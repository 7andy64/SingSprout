"""阿里云 OSS 服务端封装（S3 兼容 API）

AccessKey/SecretKey 只允许存在于服务端。
客户端直传走 STS 临时凭证（见 sts_service.py），
服务端仅在以下场景使用主凭证：
- 生成预签名 GET URL（父母端 H5 播放音频）
- TTS 合成结果上传
"""
import boto3
from botocore.config import Config as BotoConfig

from app.core.config import settings


def is_configured() -> bool:
    return bool(settings.OSS_ENDPOINT and settings.OSS_ACCESS_KEY and settings.OSS_SECRET_KEY)


def _client():
    return boto3.client(
        "s3",
        endpoint_url=f"https://{settings.OSS_ENDPOINT}",
        aws_access_key_id=settings.OSS_ACCESS_KEY,
        aws_secret_access_key=settings.OSS_SECRET_KEY,
        region_name=settings.OSS_REGION,
        config=BotoConfig(signature_version="s3v4", s3={"addressing_style": "virtual"}),
    )


def generate_presigned_get_url(oss_key: str, expires_in: int = 3600) -> str | None:
    """生成预签名下载 URL，供 H5 页面播放。OSS 未配置时返回 None。"""
    if not is_configured():
        return None
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.OSS_BUCKET, "Key": oss_key},
        ExpiresIn=expires_in,
    )


def upload_bytes(oss_key: str, data: bytes, content_type: str = "audio/wav") -> bool:
    """服务端上传字节到 OSS（用于 TTS 合成结果落盘）。返回是否成功。"""
    if not is_configured():
        return False
    _client().put_object(
        Bucket=settings.OSS_BUCKET,
        Key=oss_key,
        Body=data,
        ContentType=content_type,
    )
    return True
