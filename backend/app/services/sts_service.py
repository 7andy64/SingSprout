"""阿里云 STS 临时凭证服务

客户端（Flutter）直传 OSS 前，先调用本服务换取临时凭证，
绝不在客户端硬编码 AccessKey/SecretKey。

实现：手写阿里云 RPC 风格签名（HMAC-SHA1）调用 AssumeRole。
临时凭证通过 RAM Policy 限定只能 PutObject 到指定 prefix，
即使泄露也只能往该设备目录上传，且最多 1 小时过期。
"""
import base64
import hashlib
import hmac
import json
import urllib.parse
import uuid
from datetime import datetime, timezone

import httpx

from app.core.config import settings


class StsError(Exception):
    """STS 服务未配置或调用失败"""


def _percent_encode(s: str) -> str:
    """阿里云 POP 签名专用 URL 编码"""
    return (
        urllib.parse.quote(str(s), safe="")
        .replace("+", "%20")
        .replace("*", "%2A")
        .replace("%7E", "~")
    )


def _signed_params(params: dict[str, str]) -> dict[str, str]:
    """按阿里云 RPC 规范补齐公共参数并计算签名"""
    params = dict(params)
    params.update(
        {
            "Format": "JSON",
            "Version": "2015-04-01",
            "AccessKeyId": settings.OSS_ACCESS_KEY,
            "SignatureMethod": "HMAC-SHA1",
            "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "SignatureVersion": "1.0",
            "SignatureNonce": uuid.uuid4().hex,
        }
    )
    canonical = "&".join(
        f"{_percent_encode(k)}={_percent_encode(params[k])}"
        for k in sorted(params)
    )
    string_to_sign = f"GET&{_percent_encode('/')}&{_percent_encode(canonical)}"
    digest = hmac.new(
        (settings.OSS_SECRET_KEY + "&").encode(),
        string_to_sign.encode(),
        hashlib.sha1,
    ).digest()
    params["Signature"] = base64.b64encode(digest).decode()
    return params


async def assume_role_for_upload(device_id: str) -> dict:
    """
    为指定设备获取上传用临时凭证。

    返回: {
        access_key_id, access_key_secret, security_token, expiration,
        bucket, endpoint, region, upload_prefix
    }
    """
    if not settings.OSS_STS_ROLE_ARN:
        raise StsError("OSS_STS_ROLE_ARN 未配置，无法下发 STS 凭证")
    if not (settings.OSS_ACCESS_KEY and settings.OSS_SECRET_KEY):
        raise StsError("OSS 主凭证未配置")

    upload_prefix = f"uploads/{device_id}/"
    # 最小权限策略：仅允许上传到该设备目录
    policy = json.dumps(
        {
            "Version": "1",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": ["oss:PutObject"],
                    "Resource": [
                        f"acs:oss:*:*:{settings.OSS_BUCKET}/{upload_prefix}*"
                    ],
                }
            ],
        }
    )

    params = _signed_params(
        {
            "Action": "AssumeRole",
            "RoleArn": settings.OSS_STS_ROLE_ARN,
            "RoleSessionName": f"singsprout-{device_id[:32]}",
            "DurationSeconds": str(settings.OSS_STS_DURATION_SECONDS),
            "Policy": policy,
        }
    )

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(settings.OSS_STS_ENDPOINT, params=params)
        body = resp.json()

    if resp.status_code != 200 or "Credentials" not in body:
        raise StsError(f"STS AssumeRole 失败: {body.get('Message', resp.status_code)}")

    creds = body["Credentials"]
    return {
        "access_key_id": creds["AccessKeyId"],
        "access_key_secret": creds["AccessKeySecret"],
        "security_token": creds["SecurityToken"],
        "expiration": creds["Expiration"],
        "bucket": settings.OSS_BUCKET,
        "endpoint": settings.OSS_ENDPOINT,
        "region": settings.OSS_REGION,
        "upload_prefix": upload_prefix,
    }
