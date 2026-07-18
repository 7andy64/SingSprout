"""分享链接 API — 生成微信分享卡片、父母端 H5 收听"""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.core.security import create_access_token, verify_token, filter_text
from app.schemas.share import (
    GenerateShareRequest,
    GenerateShareResponse,
    ReplyRequest,
    ReplyResponse,
)

router = APIRouter()


@router.post("/generate", response_model=GenerateShareResponse)
async def generate_share_link(req: GenerateShareRequest):
    """
    生成音乐明信片分享链接
    App 端上传音频到 OSS 后调用此接口生成微信分享卡片链接
    """
    # 内容安全检查
    if req.text_content and settings.CONTENT_FILTER_ENABLED:
        passed, _ = filter_text(req.text_content)
        if not passed:
            raise HTTPException(status_code=400, detail="内容包含不当信息")

    # 生成访问 Token（180 天有效）
    token_data = {
        "card_id": req.card_id,
        "device_id": req.device_id,
        "audio_key": req.audio_oss_key,
    }
    token = create_access_token(token_data)
    card_id = req.card_id
    share_url = f"{settings.SHARE_LINK_BASE_URL}/{card_id}"

    expires_at = datetime.now(timezone.utc) + timedelta(
        days=settings.SHARE_LINK_EXPIRE_DAYS
    )

    # TODO: 存入数据库 (ShareLink 表)

    return GenerateShareResponse(
        card_id=card_id,
        share_url=share_url,
        expires_at=expires_at,
    )


@router.get("/card/{card_id}")
async def get_card_page(card_id: str):
    """
    父母端 H5 页面数据
    微信内打开，无需登录，展示音乐明信片
    """
    # TODO: 从数据库查询 ShareLink
    # TODO: 从 OSS 获取音频和封面
    return {
        "card_id": card_id,
        "audio_url": "",
        "cover_url": "",
        "text_content": "",
        "sender_nickname": "",
        "created_at": "",
    }


@router.post("/reply", response_model=ReplyResponse)
async def reply_to_card(req: ReplyRequest):
    """
    父母在 H5 页面录制回复
    语音: AI 自动配背景音乐
    文字: AI 朗读 + 配乐
    """
    # 验证 Token
    payload = verify_token(req.share_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="链接已过期")

    # 内容安全检查
    if req.reply_text and settings.CONTENT_FILTER_ENABLED:
        passed, _ = filter_text(req.reply_text)
        if not passed:
            raise HTTPException(status_code=400, detail="内容包含不当信息")

    # 文字回复：AI 朗读 + 配乐
    if req.reply_type == "text" and req.reply_text:
        # TODO: TTS + 自动配乐处理
        pass

    # 语音回复：AI 配伴奏
    if req.reply_type == "voice" and req.reply_audio_oss_key:
        # TODO: 语音 + AI 配乐处理
        pass

    reply_id = str(uuid.uuid4())

    # TODO: 存入数据库 (Reply 表)

    return ReplyResponse(reply_id=reply_id, status="ok")
