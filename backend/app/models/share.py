"""分享链接与明信片数据库模型"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Boolean, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class ShareLink(Base):
    """分享链接 — 孩子生成给父母的明信片链接"""
    __tablename__ = "share_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    card_id = Column(String(64), unique=True, nullable=False, index=True)
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

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    share_link_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    device_id = Column(String(64), nullable=False, index=True)
    reply_audio_oss_key = Column(String(256), nullable=True)
    reply_text = Column(Text, nullable=True)
    reply_type = Column(String(16), nullable=False)  # "voice" | "text"
    is_synced = Column(Boolean, default=False)  # 是否已同步到孩子手机
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
