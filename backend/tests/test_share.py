"""分享功能测试"""
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_generate_share_link():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/v1/share/generate",
            json={
                "card_id": "test-card-001",
                "device_id": "device-001",
                "audio_oss_key": "audio/test.mp3",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "share_url" in data
        assert "expires_at" in data


@pytest.mark.asyncio
async def test_generate_share_link_bad_content():
    """测试内容安全过滤"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/v1/share/generate",
            json={
                "card_id": "test-card-002",
                "device_id": "device-002",
                "audio_oss_key": "audio/test.mp3",
                "text_content": "包含暴力内容",
            },
        )
        assert response.status_code == 400


@pytest.mark.asyncio
async def test_reply_expired_token():
    """测试过期 Token"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/v1/share/reply",
            json={
                "share_token": "invalid-token",
                "reply_type": "text",
                "reply_text": "你好",
            },
        )
        assert response.status_code == 401
