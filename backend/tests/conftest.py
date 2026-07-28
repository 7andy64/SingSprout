"""测试配置 — 用 sqlite 内存库代替 PostgreSQL"""
import os

# 必须在任何 app 模块导入前设置，settings 在 import 时读取
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("SINGSPROUT_TEST", "true")

import pytest_asyncio

from app.core.database import engine
from app.models.share import Base


@pytest_asyncio.fixture(autouse=True)
async def _create_tables():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
