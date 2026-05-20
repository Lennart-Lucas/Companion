from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.keys import KeyBundleResponse, PreKeyUpload
from app.services import crypto_service

router = APIRouter(tags=["e2e-keys"])


@router.get("/users/{user_id}/keys", response_model=KeyBundleResponse)
async def get_user_keys(
    user_id: int,
    device_id: int | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    _user: User = Depends(get_current_active_user),
) -> KeyBundleResponse:
    return await crypto_service.fetch_key_bundle(session, user_id, device_id)


@router.post("/keys/prekeys", status_code=201)
async def upload_prekeys(
    upload: PreKeyUpload,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> dict[str, int]:
    count = await crypto_service.upload_prekeys(session, user, upload)
    return {"uploaded": count}
