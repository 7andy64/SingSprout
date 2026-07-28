"""应用配置 — 环境变量 + 默认值"""
from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── 应用 ──
    APP_NAME: str = "SingSprout"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False

    # ── 服务器 ──
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    # 逗号分隔的允许跨域来源；仅 DEBUG 模式下允许 "*"
    CORS_ORIGINS: str = ""

    # ── 数据库 ──
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/singsprout"

    # ── 对象存储 (OSS) ──
    OSS_ENDPOINT: str = ""
    OSS_ACCESS_KEY: str = ""
    OSS_SECRET_KEY: str = ""
    OSS_BUCKET: str = "singsprout-audio"
    OSS_REGION: str = "cn-hangzhou"
    # STS AssumeRole 的角色 ARN（acs:ram::UID:role/xxx）
    # 为空则 /v1/storage/sts 返回 503，客户端不允许直传
    OSS_STS_ROLE_ARN: str = ""
    OSS_STS_DURATION_SECONDS: int = 3600
    OSS_STS_ENDPOINT: str = "https://sts.aliyuncs.com"

    # ── 微信集成 ──
    WECHAT_APP_ID: str = ""
    WECHAT_APP_SECRET: str = ""

    # ── TTS (阿里云 DashScope，服务端调用) ──
    # 文字回信 → AI 朗读。走异步任务模式，避免 HTTP 同步等待超时
    DASHSCOPE_API_KEY: str = ""
    TTS_MODEL: str = "sambert-zhichu-v1"
    TTS_TASK_TIMEOUT_SECONDS: int = 120

    # ── 安全 ──
    # 无默认值 — 生产环境必须设置。开发环境 DEBUG 模式会自动生成。
    SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # ── 分享链接 ──
    SHARE_LINK_BASE_URL: str = "https://singsprout.app/s"
    SHARE_LINK_EXPIRE_DAYS: int = 180

    # ── App 更新 ──
    LATEST_VERSION: str = "0.1.0"
    MIN_VERSION: str = "0.1.0"
    APK_DOWNLOAD_URL: str = ""
    APK_FILE_SIZE: int = 0
    APK_SHA256: str = ""
    UPDATE_CHANGELOG_ZH: str = ""

    # ── 内容安全 ──
    CONTENT_FILTER_ENABLED: bool = True
    MAX_TEXT_LENGTH: int = 500
    MAX_AUDIO_DURATION_SEC: int = 60

    @field_validator("SECRET_KEY", mode="after")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if not v:
            import os
            if os.environ.get("SINGSPROUT_TEST"):
                return "test-secret-key-not-for-production"
            raise ValueError(
                "SECRET_KEY 必须设置。生产环境请使用强随机字符串（如 openssl rand -hex 32）。"
            )
        if v == "change-me-in-production" or v == "change-me-to-a-random-string":
            raise ValueError(
                "SECRET_KEY 不可使用默认值。请设置为你自己的随机字符串。"
            )
        if len(v) < 16:
            raise ValueError("SECRET_KEY 长度至少为 16 个字符。")
        return v

    model_config = {"env_file": ".env"}

    @property
    def cors_origin_list(self) -> list[str]:
        if self.DEBUG and not self.CORS_ORIGINS:
            return ["*"]
        if not self.CORS_ORIGINS:
            return []
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()
