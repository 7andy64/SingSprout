"""
声芽 SingSprout — API 服务入口
轻量级后端，仅处理：分享链接生成、明信片 H5 页面、回信同步
MVP 阶段所有创作功能完全离线，不依赖后端
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.api.routes import share, messages, health, updates, storage


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时
    yield
    # 关闭时


app = FastAPI(
    title="声芽 SingSprout API",
    version="0.1.0",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url=None,
    lifespan=lifespan,
)

# 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# 路由注册
app.include_router(health.router, tags=["Health"])
app.include_router(share.router, prefix="/v1/share", tags=["Share"])
app.include_router(messages.router, prefix="/v1/messages", tags=["Messages"])
app.include_router(updates.router, prefix="/v1/updates", tags=["Updates"])
app.include_router(storage.router, prefix="/v1/storage", tags=["Storage"])

# 静态文件 — APK 下载
import os
static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
