"""消息同步 API — App 端拉取父母回信"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.share import Reply, ShareLink
from app.schemas.share import CheckRepliesResponse, ReplyItem
from app.services import oss_service

router = APIRouter()


@router.get("/replies", response_model=CheckRepliesResponse)
async def check_replies(device_id: str, db: AsyncSession = Depends(get_db)):
    """
    App 端轮询检查是否有新的父母回信。
    只下发 TTS 已合成完成（ready）且未同步过的回信。
    """
    if not device_id:
        raise HTTPException(status_code=400, detail="缺少 device_id")

    result = await db.execute(
        select(Reply, ShareLink.card_id)
        .join(ShareLink, Reply.share_link_id == ShareLink.id)
        .where(
            Reply.device_id == device_id,
            Reply.status == "ready",
            Reply.is_synced.is_(False),
        )
        .order_by(Reply.created_at)
    )
    rows = result.all()

    items = [
        ReplyItem(
            reply_id=str(reply.id),
            card_id=card_id,
            reply_audio_url=(
                oss_service.generate_presigned_get_url(reply.reply_audio_oss_key)
                if reply.reply_audio_oss_key
                else None
            ),
            reply_text=reply.reply_text,
            reply_type=reply.reply_type,
            created_at=reply.created_at,
        )
        for reply, card_id in rows
    ]

    if rows:
        await db.execute(
            update(Reply)
            .where(Reply.id.in_([reply.id for reply, _ in rows]))
            .values(is_synced=True)
        )
        await db.commit()

    return CheckRepliesResponse(replies=items)
