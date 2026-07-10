from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.media_title import (
    MediaTitleCreate,
    MediaTitleListResponse,
    MediaTitleResponse,
    MediaTitleUpdate,
)
from app.schemas.media_watch_entry import (
    MediaWatchEntryCreate,
    MediaWatchEntryListResponse,
    MediaWatchEntryResponse,
)
from app.services import media_title_service, media_watch_entry_service

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


@router.patch("/{media_title_id}", response_model=MediaTitleResponse)
async def update_media_title(
    media_title_id: int,
    body: MediaTitleUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaTitleResponse:
    media_title = await media_title_service.update_media_title(
        session, user, media_title_id, body
    )
    return MediaTitleResponse.model_validate(media_title)


@router.post("/{media_title_id}/refresh", response_model=MediaTitleResponse)
async def refresh_media_title(
    media_title_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaTitleResponse:
    media_title = await media_title_service.refresh_media_title_from_imdb(
        session, user, media_title_id
    )
    return MediaTitleResponse.model_validate(media_title)


@router.get(
    "/{media_title_id}/watch-entries",
    response_model=MediaWatchEntryListResponse,
)
async def list_media_watch_entries(
    media_title_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaWatchEntryListResponse:
    items = await media_watch_entry_service.list_watch_entries(
        session, user, media_title_id
    )
    return MediaWatchEntryListResponse(
        items=[
            media_watch_entry_service.watch_entry_to_response(item) for item in items
        ]
    )


@router.post(
    "/{media_title_id}/watch-entries",
    response_model=MediaWatchEntryResponse,
    status_code=201,
)
async def create_media_watch_entry(
    media_title_id: int,
    body: MediaWatchEntryCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> MediaWatchEntryResponse:
    entry = await media_watch_entry_service.create_watch_entry(
        session, user, media_title_id, body
    )
    return media_watch_entry_service.watch_entry_to_response(entry)


@router.delete("/{media_title_id}/watch-entries/{entry_id}", status_code=204)
async def delete_media_watch_entry(
    media_title_id: int,
    entry_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await media_watch_entry_service.delete_watch_entry(
        session, user, media_title_id, entry_id
    )


@router.delete("/{media_title_id}", status_code=204)
async def delete_media_title(
    media_title_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await media_title_service.delete_media_title(session, user, media_title_id)
