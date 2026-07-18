"""应用配置 — 环境变量 + 默认值"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── 应用 ──
    APP_NAME: str = "SingSprout"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False

    # ── 服务器 ──
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    CORS_ORIGINS: list[str] = ["*"]

    # ── 数据库 ──
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/singsprout"

    # ── 对象存储 (OSS) ──
    OSS_ENDPOINT: str = ""
    OSS_ACCESS_KEY: str = ""
    OSS_SECRET_KEY: str = ""
    OSS_BUCKET: str = "singsprout-audio"
    OSS_REGION: str = "cn-hangzhou"

    # ── 微信集成 ──
    WECHAT_APP_ID: str = ""
    WECHAT_APP_SECRET: str = ""

    # ── 安全 ──
    SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # ── 分享链接 ──
    SHARE_LINK_BASE_URL: str = "https://singsprout.app/s"
    SHARE_LINK_EXPIRE_DAYS: int = 180

    # ── 内容安全 ──
    CONTENT_FILTER_ENABLED: bool = True
    MAX_TEXT_LENGTH: int = 500
    MAX_AUDIO_DURATION_SEC: int = 60

    model_config = {"env_file": ".env"}


settings = Settings()
