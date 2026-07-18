"""安全工具 — JWT 生成与验证、内容过滤"""
import re
from datetime import datetime, timedelta, timezone

from jose import jwt

from app.core.config import settings


def create_access_token(data: dict) -> str:
    """生成 JWT — 用于分享链接认证"""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def verify_token(token: str) -> dict | None:
    """验证 JWT"""
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except Exception:
        return None


# ── 简单儿童安全内容过滤 ──
# 生产环境应接入专业敏感词服务
_BLOCKED_PATTERNS = [
    r"(暴力|自杀|自残|色情|歧视|恐怖|毒品|赌博)",
]


def filter_text(text: str) -> tuple[bool, str]:
    """
    过滤不当文本
    返回: (是否通过, 清理后文本)
    """
    cleaned = text[: settings.MAX_TEXT_LENGTH]
    for pattern in _BLOCKED_PATTERNS:
        if re.search(pattern, cleaned):
            return False, ""
    return True, cleaned
