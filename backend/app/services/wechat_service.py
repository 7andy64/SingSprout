"""微信 JS-SDK 签名服务

H5 分享卡片要在微信内显示自定义缩略图/标题/描述，
必须先用 jsapi_ticket 生成签名完成 wx.config。

流程：access_token(7200s 缓存) → jsapi_ticket(7200s 缓存) → sha1 签名
"""
import hashlib
import secrets
import time

import httpx

from app.core.config import settings

_API_BASE = "https://api.weixin.qq.com/cgi-bin"


class WeChatError(Exception):
    """微信配置缺失或接口调用失败"""


class WeChatService:
    def __init__(self) -> None:
        self._access_token: str | None = None
        self._token_expire_at: float = 0
        self._jsapi_ticket: str | None = None
        self._ticket_expire_at: float = 0

    async def _get_access_token(self) -> str:
        now = time.time()
        # 提前 5 分钟刷新，避免边界过期
        if self._access_token and now < self._token_expire_at - 300:
            return self._access_token
        if not (settings.WECHAT_APP_ID and settings.WECHAT_APP_SECRET):
            raise WeChatError("WECHAT_APP_ID / WECHAT_APP_SECRET 未配置")

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{_API_BASE}/token",
                params={
                    "grant_type": "client_credential",
                    "appid": settings.WECHAT_APP_ID,
                    "secret": settings.WECHAT_APP_SECRET,
                },
            )
            body = resp.json()
        if "access_token" not in body:
            raise WeChatError(f"获取 access_token 失败: {body.get('errmsg', body)}")

        self._access_token = body["access_token"]
        self._token_expire_at = now + int(body.get("expires_in", 7200))
        return self._access_token

    async def _get_jsapi_ticket(self) -> str:
        now = time.time()
        if self._jsapi_ticket and now < self._ticket_expire_at - 300:
            return self._jsapi_ticket

        token = await self._get_access_token()
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{_API_BASE}/ticket/getticket",
                params={"access_token": token, "type": "jsapi"},
            )
            body = resp.json()
        if body.get("errcode") != 0:
            raise WeChatError(f"获取 jsapi_ticket 失败: {body.get('errmsg', body)}")

        self._jsapi_ticket = body["ticket"]
        self._ticket_expire_at = now + int(body.get("expires_in", 7200))
        return self._jsapi_ticket

    async def jsapi_signature(self, url: str) -> dict:
        """
        生成 wx.config 所需签名。
        url 必须是调用 JS-SDK 页面的完整 URL（# 之前部分），
        由前端原样上传，服务端不做任何加工。
        """
        ticket = await self._get_jsapi_ticket()
        nonce_str = secrets.token_hex(8)
        timestamp = int(time.time())

        # 参数按 key 字典序拼接（jsapi_ticket < noncestr < timestamp < url）
        raw = (
            f"jsapi_ticket={ticket}&noncestr={nonce_str}"
            f"&timestamp={timestamp}&url={url}"
        )
        signature = hashlib.sha1(raw.encode()).hexdigest()

        return {
            "appId": settings.WECHAT_APP_ID,
            "timestamp": timestamp,
            "nonceStr": nonce_str,
            "signature": signature,
        }


wechat_service = WeChatService()
