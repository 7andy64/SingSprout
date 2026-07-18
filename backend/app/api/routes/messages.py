"""消息同步 API — App 端拉取父母回信"""
from fastapi import APIRouter, HTTPException

from app.schemas.share import CheckRepliesResponse, ReplyItem

router = APIRouter()


@router.get("/replies", response_model=CheckRepliesResponse)
async def check_replies(device_id: str):
    """
    App 端轮询检查是否有新的父母回信
    孩子在联网时自动调用此接口
    """
    if not device_id:
        raise HTTPException(status_code=400, detail="缺少 device_id")

    # TODO: 从数据库查询该设备未同步的回信
    replies: list[ReplyItem] = []

    return CheckRepliesResponse(replies=replies)
