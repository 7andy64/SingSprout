"""存储 API — STS 临时凭证下发

客户端直传 OSS 的唯一入口。AccessKey/SecretKey 只存在服务端，
客户端每次上传前用 device_id 换取限时、限前缀的临时凭证。
"""
from fastapi import APIRouter, HTTPException

from app.schemas.storage import StsTokenResponse
from app.services.sts_service import StsError, assume_role_for_upload

router = APIRouter()


@router.get("/sts", response_model=StsTokenResponse)
async def get_sts_token(device_id: str):
    """
    下发 OSS 直传 STS 临时凭证。
    凭证被 RAM Policy 限定为只能 PutObject 到 uploads/{device_id}/ 前缀。
    """
    if not device_id:
        raise HTTPException(status_code=400, detail="缺少 device_id")
    try:
        creds = await assume_role_for_upload(device_id)
    except StsError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return StsTokenResponse(**creds)
