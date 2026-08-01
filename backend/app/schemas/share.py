"""分享相关 Pydantic schemas"""
from datetime import datetime
from pydantic import BaseModel, Field


class GenerateShareRequest(BaseModel):
    card_id: str = Field(..., min_length=1, max_length=64)
    device_id: str = Field(..., min_length=1, max_length=64)
    audio_oss_key: str = Field(..., min_length=1, max_length=256)
    cover_oss_key: str | None = Field(None, max_length=256)
    text_content: str | None = Field(None, max_length=500)


class GenerateShareResponse(BaseModel):
    card_id: str
    share_url: str
    expires_at: datetime


class ReplyRequest(BaseModel):
    share_token: str
    reply_type: str = Field(..., pattern="^(voice|text)$")  # voice or text
    reply_audio_oss_key: str | None = None
    reply_text: str | None = Field(None, max_length=500)


class ReplyResponse(BaseModel):
    reply_id: str
    status: str  # "processing"（文字回复 TTS 合成中）| "ready"
    task_id: str | None = None  # 文字回复时返回，供轮询 tts-status


class TtsStatusResponse(BaseModel):
    task_id: str
    status: str  # processing | ready | failed
    error: str | None = None


class CheckRepliesRequest(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=64)


class ReplyItem(BaseModel):
    reply_id: str
    card_id: str
    reply_audio_url: str | None
    reply_text: str | None
    reply_type: str
    created_at: datetime


class CheckRepliesResponse(BaseModel):
    replies: list[ReplyItem]
