from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.keys import DeviceResponse, KeyBundleUpload
from app.services import crypto_service

router = APIRouter(prefix="/devices", tags=["e2e-keys"])


@router.post("", response_model=DeviceResponse, status_code=201)
async def register_device(
    bundle: KeyBundleUpload,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> DeviceResponse:
    device = await crypto_service.register_device(session, user, bundle)
    return device
