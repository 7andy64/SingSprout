"""阿里云 DashScope TTS 合成服务（服务端调用）

使用 sambert 系列模型的异步任务 API：
  1. POST /api/v1/services/audio/tts/{model} (X-DashScope-Async: enable)
  2. GET  /api/v1/tasks/{task_id} 轮询至 SUCCEEDED
  3. 下载 output.audio_url 得到音频字节

注意：接口路径以 DashScope 当前文档为准，如模型更换只需调整 TTS_MODEL 配置。
"""
import asyncio
import base64

import httpx

from app.core.config import settings

_TTS_BASE = "https://dashscope.aliyuncs.com/api/v1/services/audio/tts"
_TASK_BASE = "https://dashscope.aliyuncs.com/api/v1/tasks"


class TtsError(Exception):
    """TTS 未配置或合成失败"""


async def synthesize_speech(text: str) -> bytes:
    """合成文本为 WAV 音频字节。未配置 API Key 时抛 TtsError。"""
    if not settings.DASHSCOPE_API_KEY:
        raise TtsError("DASHSCOPE_API_KEY 未配置")

    headers = {
        "Authorization": f"Bearer {settings.DASHSCOPE_API_KEY}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
    }
    payload = {
        "model": settings.TTS_MODEL,
        "input": {"text": text},
        "parameters": {"format": "wav", "sample_rate": 16000},
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{_TTS_BASE}/{settings.TTS_MODEL}", headers=headers, json=payload
        )
        if resp.status_code != 200:
            raise TtsError(f"TTS 任务创建失败: HTTP {resp.status_code}")
        body = resp.json()
        task_id = (body.get("output") or {}).get("task_id")
        if not task_id:
            raise TtsError(f"TTS 任务创建失败: {body}")

        audio_url = await _poll_task(client, task_id, headers)
        if not audio_url:
            raise TtsError("TTS 任务超时未返回音频地址")

        audio_resp = await client.get(audio_url, timeout=60)
        if audio_resp.status_code != 200:
            raise TtsError(f"TTS 音频下载失败: HTTP {audio_resp.status_code}")
        return audio_resp.content


async def _poll_task(
    client: httpx.AsyncClient, task_id: str, headers: dict
) -> str | None:
    """轮询 DashScope 任务直至完成，返回音频 URL"""
    deadline = asyncio.get_event_loop().time() + settings.TTS_TASK_TIMEOUT_SECONDS
    while asyncio.get_event_loop().time() < deadline:
        resp = await client.get(f"{_TASK_BASE}/{task_id}", headers=headers)
        if resp.status_code == 200:
            output = (resp.json().get("output")) or {}
            status = output.get("task_status")
            if status == "SUCCEEDED":
                return output.get("audio_url")
            if status in ("FAILED", "CANCELED"):
                raise TtsError(f"TTS 任务失败: {output.get('message', status)}")
        await asyncio.sleep(1.5)
    return None
