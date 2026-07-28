"""分享链接与明信片数据库模型"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Boolean, Text, Integer, Uuid
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class ShareLink(Base):
    """分享链接 — 孩子生成给父母的明信片链接"""
    __tablename__ = "share_links"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    card_id = Column(String(64), unique=True, nullable=False, index=True)
    # 短链接码：share_url 的最后一段。唯一索引 + 生成端冲突重试，防高并发重复
    short_code = Column(String(16), unique=True, nullable=False, index=True)
    device_id = Column(String(64), nullable=False, index=True)
    audio_oss_key = Column(String(256), nullable=False)
    cover_oss_key = Column(String(256), nullable=True)
    text_content = Column(Text, nullable=True)
    share_url = Column(String(512), nullable=False, unique=True)
    access_token = Column(String(512), nullable=False)
    is_active = Column(Boolean, default=True)
    view_count = Column(Integer, default=0)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


class Reply(Base):
    """父母回信"""
    __tablename__ = "replies"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    share_link_id = Column(Uuid, nullable=False, index=True)
    device_id = Column(String(64), nullable=False, index=True)
    reply_audio_oss_key = Column(String(256), nullable=True)
    reply_text = Column(Text, nullable=True)
    reply_type = Column(String(16), nullable=False)  # "voice" | "text"
    # TTS 合成状态：processing → ready | failed（文字回复为异步任务）
    status = Column(String(16), nullable=False, default="ready", index=True)
    # TTS 异步任务 ID（文字回复时生成，供客户端轮询）
    task_id = Column(String(32), nullable=True, unique=True, index=True)
    # TTS 任务失败时的错误信息
    task_error = Column(Text, nullable=True)
    is_synced = Column(Boolean, default=False)  # 是否已同步到孩子手机
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
