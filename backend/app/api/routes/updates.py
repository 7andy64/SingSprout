"""App 更新检查 API — 返回最新版本信息供客户端比对"""
from fastapi import APIRouter

from app.core.config import settings

router = APIRouter()


@router.get("/check")
async def check_update(platform: str = "android", version: str = "0.0.0"):
    """
    App 启动时调用，比对版本号决定是否提示更新。
    - platform: android | ios
    - version: 当前客户端版本号 (semver)
    """
    latest = settings.LATEST_VERSION
    min_ver = settings.MIN_VERSION
    download_url = settings.APK_DOWNLOAD_URL

    has_update = _version_greater(latest, version)
    force_update = _version_greater(min_ver, version)

    return {
        "has_update": has_update or force_update,
        "force_update": force_update,
        "latest_version": latest,
        "min_version": min_ver,
        "download_url": download_url if platform == "android" else None,
        "file_size": settings.APK_FILE_SIZE,
        "sha256": settings.APK_SHA256,
        "changelog": settings.UPDATE_CHANGELOG_ZH,
    }


def _version_greater(a: str, b: str) -> bool:
    """简单的 semver 比较：a > b"""
    try:
        parts_a = [int(x) for x in a.split(".")]
        parts_b = [int(x) for x in b.split(".")]
        # 补齐长度
        while len(parts_a) < 3:
            parts_a.append(0)
        while len(parts_b) < 3:
            parts_b.append(0)
        for i in range(3):
            if parts_a[i] > parts_b[i]:
                return True
            if parts_a[i] < parts_b[i]:
                return False
        return False
    except (ValueError, IndexError):
        return False
