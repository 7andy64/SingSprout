"""数据库层与异步流程测试"""
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_generate_and_fetch_card_by_short_code():
    """生成链接后应能按短码查到 H5 页面数据"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/v1/share/generate",
            json={
                "card_id": "card-short-001",
                "device_id": "device-001",
                "audio_oss_key": "uploads/device-001/a.m4a",
                "text_content": "给妈妈的歌",
            },
        )
        assert resp.status_code == 200
        share_url = resp.json()["share_url"]
        short_code = share_url.rsplit("/", 1)[-1]
        assert len(short_code) == 8

        page = await client.get(f"/v1/share/s/{short_code}")
        assert page.status_code == 200
        data = page.json()
        assert data["card_id"] == "card-short-001"
        assert data["text_content"] == "给妈妈的歌"
        assert data["share_token"]


@pytest.mark.asyncio
async def test_card_not_found():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/v1/share/s/notexist")
        assert resp.status_code == 404


@pytest.mark.asyncio
async def test_text_reply_is_async_and_voice_reply_syncs():
    """文字回复返回 processing + task_id；语音回复直接 ready 并可被孩子拉到"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        gen = await client.post(
            "/v1/share/generate",
            json={
                "card_id": "card-reply-001",
                "device_id": "device-kid-1",
                "audio_oss_key": "uploads/device-kid-1/a.m4a",
            },
        )
        short_code = gen.json()["share_url"].rsplit("/", 1)[-1]
        page = await client.get(f"/v1/share/s/{short_code}")
        token = page.json()["share_token"]

        # 文字回复 → 异步 TTS
        text_reply = await client.post(
            "/v1/share/reply",
            json={
                "share_token": token,
                "reply_type": "text",
                "reply_text": "宝贝唱得真好",
            },
        )
        assert text_reply.status_code == 200
        body = text_reply.json()
        assert body["status"] == "processing"
        assert body["task_id"]

        # 语音回复 → 立即 ready
        voice_reply = await client.post(
            "/v1/share/reply",
            json={
                "share_token": token,
                "reply_type": "voice",
                "reply_audio_oss_key": "replies/voice-1.m4a",
            },
        )
        assert voice_reply.status_code == 200
        assert voice_reply.json()["status"] == "ready"
        assert voice_reply.json()["task_id"] is None

        # 孩子端拉取：只有语音回信（文字那条还在 processing）
        check = await client.get("/v1/messages/replies?device_id=device-kid-1")
        assert check.status_code == 200
        replies = check.json()["replies"]
        assert len(replies) == 1
        assert replies[0]["reply_type"] == "voice"

        # 已同步的信不应重复下发
        again = await client.get("/v1/messages/replies?device_id=device-kid-1")
        assert again.json()["replies"] == []


@pytest.mark.asyncio
async def test_tts_status_unknown_task():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/v1/share/tts-status/does-not-exist")
        assert resp.status_code == 404


@pytest.mark.asyncio
async def test_sts_not_configured_returns_503():
    """未配置 RAM 角色时 STS 接口必须拒绝，而不是泄露主凭证"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/v1/storage/sts?device_id=device-001")
        assert resp.status_code == 503


@pytest.mark.asyncio
async def test_wechat_signature_not_configured_returns_503():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/v1/share/wechat/jsapi-signature?url=https://x.app/s/abc")
        assert resp.status_code == 503
