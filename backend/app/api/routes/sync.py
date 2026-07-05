from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.sync import SyncChangesResponse
from app.services import sync_service

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/changes", response_model=SyncChangesResponse)
async def get_sync_changes(
    since: datetime | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> SyncChangesResponse:
    payload = await sync_service.get_sync_changes(session, user, since=since)
    return SyncChangesResponse.model_validate(payload)
