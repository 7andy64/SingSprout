"""存储相关 Pydantic schemas"""
from pydantic import BaseModel


class StsTokenResponse(BaseModel):
    """STS 临时凭证 — 客户端据此直传 OSS，主凭证永不下发"""

    access_key_id: str
    access_key_secret: str
    security_token: str
    expiration: str
    bucket: str
    endpoint: str
    region: str
    upload_prefix: str  # 客户端必须上传到此前缀下（服务端策略已限定）
