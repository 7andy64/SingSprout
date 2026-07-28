"""分享链接 API — 生成微信分享卡片、父母端 H5 收听"""
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, verify_token, filter_text
from app.models.share import Reply, ShareLink
from app.schemas.share import (
    GenerateShareRequest,
    GenerateShareResponse,
    ReplyRequest,
    ReplyResponse,
    TtsStatusResponse,
)
from app.services import oss_service, tts_tasks
from app.services.wechat_service import WeChatError, wechat_service

router = APIRouter()

# 短码冲突重试次数。short_code 8 字符 base64url，碰撞概率极低，
# 重试只为兜住并发下恰好撞码的极端情况
_SHORT_CODE_MAX_ATTEMPTS = 5


def _new_short_code() -> str:
    # 8 字符 URL 安全短码（约 48 bit 熵）
    return secrets.token_urlsafe(6)


@router.post("/generate", response_model=GenerateShareResponse)
async def generate_share_link(
    req: GenerateShareRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    生成音乐明信片分享链接
    App 端上传音频到 OSS 后调用此接口生成微信分享卡片链接
    """
    # 内容安全检查
    if req.text_content and settings.CONTENT_FILTER_ENABLED:
        passed, _ = filter_text(req.text_content)
        if not passed:
            raise HTTPException(status_code=400, detail="内容包含不当信息")

    token = create_access_token(
        {
            "card_id": req.card_id,
            "device_id": req.device_id,
            "audio_key": req.audio_oss_key,
        }
    )
    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.SHARE_LINK_EXPIRE_DAYS
    )

    # 生成短码并落库；唯一索引冲突时换新码重试
    link: ShareLink | None = None
    for _ in range(_SHORT_CODE_MAX_ATTEMPTS):
        short_code = _new_short_code()
        link = ShareLink(
            card_id=req.card_id,
            short_code=short_code,
            device_id=req.device_id,
            audio_oss_key=req.audio_oss_key,
            cover_oss_key=req.cover_oss_key,
            text_content=req.text_content,
            share_url=f"{settings.SHARE_LINK_BASE_URL}/{short_code}",
            access_token=token,
            expires_at=expires_at,
        )
        db.add(link)
        try:
            await db.commit()
            break
        except IntegrityError:
            await db.rollback()
            link = None
    if link is None:
        raise HTTPException(status_code=500, detail="分享链接生成失败，请重试")

    return GenerateShareResponse(
        card_id=req.card_id,
        share_url=link.share_url,
        expires_at=expires_at,
    )


@router.get("/s/{short_code}")
async def get_card_by_short_code(
    short_code: str,
    db: AsyncSession = Depends(get_db),
):
    """父母端 H5 页面数据 — 按短码查询（微信内打开，无需登录）"""
    result = await db.execute(
        select(ShareLink).where(
            ShareLink.short_code == short_code,
            ShareLink.is_active.is_(True),
        )
    )
    link = result.scalar_one_or_none()
    if link is None:
        raise HTTPException(status_code=404, detail="明信片不存在或已删除")
    # sqlite 返回 naive datetime，PG 返回 aware；统一按 UTC 处理
    expires_at = link.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="链接已过期")

    link.view_count += 1
    await db.commit()

    return {
        "card_id": link.card_id,
        "short_code": link.short_code,
        "audio_url": oss_service.generate_presigned_get_url(link.audio_oss_key),
        "cover_url": (
            oss_service.generate_presigned_get_url(link.cover_oss_key)
            if link.cover_oss_key
            else None
        ),
        "text_content": link.text_content,
        "share_token": link.access_token,
        "created_at": link.created_at.isoformat(),
    }


@router.get("/card/{card_id}")
async def get_card_page(card_id: str, db: AsyncSession = Depends(get_db)):
    """父母端 H5 页面数据 — 按 card_id 查询"""
    result = await db.execute(
        select(ShareLink).where(
            ShareLink.card_id == card_id,
            ShareLink.is_active.is_(True),
        )
    )
    link = result.scalar_one_or_none()
    if link is None:
        raise HTTPException(status_code=404, detail="明信片不存在或已删除")
    return {
        "card_id": link.card_id,
        "short_code": link.short_code,
        "audio_url": oss_service.generate_presigned_get_url(link.audio_oss_key),
        "cover_url": (
            oss_service.generate_presigned_get_url(link.cover_oss_key)
            if link.cover_oss_key
            else None
        ),
        "text_content": link.text_content,
        "share_token": link.access_token,
        "created_at": link.created_at.isoformat(),
    }


@router.post("/reply", response_model=ReplyResponse)
async def reply_to_card(
    req: ReplyRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    父母在 H5 页面录制回复
    - 语音回复：音频已由 H5 直传 OSS，直接落库
    - 文字回复：TTS 合成为异步任务，立即返回 task_id 供轮询
    """
    payload = verify_token(req.share_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="链接已过期")

    if req.reply_text and settings.CONTENT_FILTER_ENABLED:
        passed, _ = filter_text(req.reply_text)
        if not passed:
            raise HTTPException(status_code=400, detail="内容包含不当信息")

    # 找到对应分享链接，确认仍在有效期内
    result = await db.execute(
        select(ShareLink).where(ShareLink.card_id == payload["card_id"])
    )
    link = result.scalar_one_or_none()
    if link is None or not link.is_active:
        raise HTTPException(status_code=404, detail="明信片不存在")

    is_text = req.reply_type == "text" and req.reply_text
    reply = Reply(
        share_link_id=link.id,
        device_id=payload["device_id"],
        reply_type=req.reply_type,
        reply_text=req.reply_text,
        reply_audio_oss_key=req.reply_audio_oss_key,
        # 文字回复等 TTS 完成后再置 ready
        status="processing" if is_text else "ready",
    )
    db.add(reply)
    await db.commit()

    task_id = None
    if is_text:
        task_id = tts_tasks.start_text_reply_tts(str(reply.id), req.reply_text)

    return ReplyResponse(
        reply_id=str(reply.id),
        status=reply.status,
        task_id=task_id,
    )


@router.get("/tts-status/{task_id}", response_model=TtsStatusResponse)
async def get_tts_status(task_id: str):
    """H5 轮询文字回复的 TTS 合成状态"""
    task = await tts_tasks.get_task_status(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    return TtsStatusResponse(
        task_id=task_id,
        status=task["status"],
        error=task.get("error"),
    )


@router.get("/wechat/jsapi-signature")
async def get_wechat_jsapi_signature(url: str):
    """
    微信 JS-SDK 签名 — H5 页面用当前完整 URL（# 之前）换取 wx.config 参数
    缺少此接口时分享卡片会退化为无缩略图的普通链接
    """
    if not url:
        raise HTTPException(status_code=400, detail="缺少 url 参数")
    try:
        return await wechat_service.jsapi_signature(url)
    except WeChatError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
