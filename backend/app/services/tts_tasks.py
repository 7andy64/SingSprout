"""TTS 异步任务注册表

设计要点（对应 TTS 超时风险）：
- HTTP 接口立即返回 task_id，不阻塞等待合成完成
- 合成在后台 asyncio 任务中执行，完成后：
  1. 音频上传 OSS
  2. 更新 replies 表 status = ready + reply_audio_oss_key
  3. 客户端通过 /v1/share/tts-status/{task_id} 轮询
- 任务状态持久化在 replies 表的 task_id / task_error 列，进程重启不丢失。
"""
import asyncio
import logging
import uuid

from sqlalchemy import select

from app.core.database import async_session_factory
from app.models.share import Reply
from app.services import oss_service, tts_service

logger = logging.getLogger(__name__)


def start_text_reply_tts(reply_id: str, text: str) -> str:
    """创建 TTS 后台任务，返回 task_id。

    任务状态写入 replies 表，无需额外内存注册表。
    """
    task_id = uuid.uuid4().hex
    asyncio.create_task(_run(task_id, reply_id, text))
    return task_id


async def get_task_status(task_id: str) -> dict | None:
    """从 replies 表查询 TTS 任务状态"""
    async with async_session_factory() as session:
        result = await session.execute(
            select(Reply).where(Reply.task_id == task_id)
        )
        reply = result.scalar_one_or_none()
        if reply is None:
            return None
        return {
            "status": reply.status,
            "reply_id": str(reply.id),
            "error": reply.task_error,
        }


async def _run(task_id: str, reply_id: str, text: str) -> None:
    # 先将 task_id 写入 Reply 记录
    await _set_task_id(reply_id, task_id)
    try:
        audio_bytes = await tts_service.synthesize_speech(text)
        oss_key = f"replies/{reply_id}.wav"
        if not oss_service.upload_bytes(oss_key, audio_bytes):
            raise tts_service.TtsError("OSS 未配置，无法保存合成结果")
        await _update_reply(reply_id, "ready", oss_key, None)
    except Exception as exc:
        logger.exception("TTS 任务失败 task_id=%s", task_id)
        try:
            await _update_reply(reply_id, "failed", None, str(exc))
        except Exception:
            logger.exception("回信状态更新失败 reply_id=%s", reply_id)


async def _set_task_id(reply_id: str, task_id: str) -> None:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Reply).where(Reply.id == uuid.UUID(reply_id))
        )
        reply = result.scalar_one_or_none()
        if reply is not None:
            reply.task_id = task_id
            await session.commit()


async def _update_reply(
    reply_id: str, status: str, oss_key: str | None, error: str | None
) -> None:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Reply).where(Reply.id == uuid.UUID(reply_id))
        )
        reply = result.scalar_one_or_none()
        if reply is None:
            return
        reply.status = status
        if oss_key:
            reply.reply_audio_oss_key = oss_key
        if error:
            reply.task_error = error
        await session.commit()
