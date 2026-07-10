from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.media_title import (
    MediaTitleCreate,
    MediaTitleListResponse,
    MediaTitleResponse,
)
from app.services import media_title_service

router = APIRouter(prefix="/media-titles", tags=["media-titles"])


@router.post("", response_model=MediaTitleResponse, status_code=201)
async def create_media_title(
    body: MediaTitleCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaTitleResponse:
    media_title = await media_title_service.create_media_title(session, user, body)
    return MediaTitleResponse.model_validate(media_title)


@router.get("", response_model=MediaTitleListResponse)
async def list_media_titles(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaTitleListResponse:
    items, total = await media_title_service.list_media_titles(
        session, user, limit=limit, offset=offset
    )
    return MediaTitleListResponse(
        items=[MediaTitleResponse.model_validate(item) for item in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{media_title_id}", response_model=MediaTitleResponse)
async def get_media_title(
    media_title_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaTitleResponse:
    media_title = await media_title_service.get_media_title(
        session, user, media_title_id
    )
    return MediaTitleResponse.model_validate(media_title)


@router.delete("/{media_title_id}", status_code=204)
async def delete_media_title(
    media_title_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await media_title_service.delete_media_title(session, user, media_title_id)
