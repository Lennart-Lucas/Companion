from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.media_title import WATCH_STATUS_PLAN_TO_WATCH, MediaTitle
from app.models.media_watch_entry import MediaWatchEntry
from app.models.user import User
from app.schemas.imdb import ImdbTitleDetailResponse
from app.schemas.media_title import MediaTitleCreate, MediaTitleUpdate
from app.services.imdb_api_client import imdb_api_client, normalize_imdb_id
from app.services.productivity_helpers import (
    apply_list_filters,
    clamp_pagination,
    soft_delete,
)


async def _load_media_title(
    session: AsyncSession, media_title_id: int, user_id: int
) -> MediaTitle:
    result = await session.execute(
        select(MediaTitle).where(
            MediaTitle.id == media_title_id,
            MediaTitle.user_id == user_id,
            MediaTitle.deleted_at.is_(None),
        )
    )
    media_title = result.scalar_one_or_none()
    if media_title is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Media title not found",
        )
    return media_title


async def _find_by_imdb_id(
    session: AsyncSession, user_id: int, imdb_id: str
) -> MediaTitle | None:
    result = await session.execute(
        select(MediaTitle).where(
            MediaTitle.user_id == user_id,
            MediaTitle.imdb_id == imdb_id,
            MediaTitle.deleted_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def _find_deleted_by_imdb_id(
    session: AsyncSession, user_id: int, imdb_id: str
) -> MediaTitle | None:
    result = await session.execute(
        select(MediaTitle).where(
            MediaTitle.user_id == user_id,
            MediaTitle.imdb_id == imdb_id,
            MediaTitle.deleted_at.is_not(None),
        )
    )
    return result.scalar_one_or_none()


def _apply_imdb_snapshot(
    media_title: MediaTitle, detail: ImdbTitleDetailResponse
) -> None:
    media_title.name = detail.name
    media_title.media_type = detail.media_type
    media_title.year = detail.year
    media_title.description = detail.description
    media_title.poster_url = detail.poster_url
    media_title.imdb_url = detail.imdb_url
    media_title.rating = detail.rating
    media_title.vote_count = detail.vote_count
    media_title.genres = detail.genres or None
    media_title.runtime_minutes = detail.runtime_minutes
    media_title.cast = detail.cast or None


def _apply_detail_to_media_title(
    media_title: MediaTitle, detail: ImdbTitleDetailResponse
) -> None:
    _apply_imdb_snapshot(media_title, detail)
    media_title.deleted_at = None
    media_title.watch_status = WATCH_STATUS_PLAN_TO_WATCH
    media_title.user_rating = None
    media_title.notes = None


async def _clear_watch_entries(session: AsyncSession, media_title_id: int) -> None:
    result = await session.execute(
        select(MediaWatchEntry).where(
            MediaWatchEntry.media_title_id == media_title_id,
            MediaWatchEntry.deleted_at.is_(None),
        )
    )
    for entry in result.scalars().all():
        await soft_delete(entry)


def _detail_to_media_title(
    user_id: int, detail: ImdbTitleDetailResponse
) -> MediaTitle:
    return MediaTitle(
        user_id=user_id,
        imdb_id=detail.imdb_id,
        name=detail.name,
        media_type=detail.media_type,
        year=detail.year,
        description=detail.description,
        poster_url=detail.poster_url,
        imdb_url=detail.imdb_url,
        rating=detail.rating,
        vote_count=detail.vote_count,
        genres=detail.genres or None,
        runtime_minutes=detail.runtime_minutes,
        cast=detail.cast or None,
    )


async def get_media_title(
    session: AsyncSession, user: User, media_title_id: int
) -> MediaTitle:
    return await _load_media_title(session, media_title_id, user.id)


async def update_media_title(
    session: AsyncSession,
    user: User,
    media_title_id: int,
    data: MediaTitleUpdate,
) -> MediaTitle:
    media_title = await _load_media_title(session, media_title_id, user.id)
    updates = data.model_dump(exclude_unset=True)
    if not updates:
        return media_title
    for field, value in updates.items():
        setattr(media_title, field, value)
    await session.flush()
    await session.refresh(media_title)
    return media_title


async def refresh_media_title_from_imdb(
    session: AsyncSession, user: User, media_title_id: int
) -> MediaTitle:
    media_title = await _load_media_title(session, media_title_id, user.id)
    detail = await imdb_api_client.get_title(media_title.imdb_id)
    _apply_imdb_snapshot(media_title, detail)
    await session.flush()
    await session.refresh(media_title)
    return media_title


async def create_media_title(
    session: AsyncSession, user: User, data: MediaTitleCreate
) -> MediaTitle:
    imdb_id = normalize_imdb_id(data.imdb_id)
    existing = await _find_by_imdb_id(session, user.id, imdb_id)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This title is already in your library",
        )

    detail = await imdb_api_client.get_title(imdb_id)

    deleted = await _find_deleted_by_imdb_id(session, user.id, imdb_id)
    if deleted is not None:
        _apply_detail_to_media_title(deleted, detail)
        await _clear_watch_entries(session, deleted.id)
        await session.flush()
        await session.refresh(deleted)
        return deleted

    media_title = _detail_to_media_title(user.id, detail)
    session.add(media_title)
    await session.flush()
    await session.refresh(media_title)
    return media_title


async def list_media_titles(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[MediaTitle], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(MediaTitle).where(MediaTitle.user_id == user.id)
    base = apply_list_filters(base, MediaTitle, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(MediaTitle).where(
        MediaTitle.user_id == user.id
    )
    count_stmt = apply_list_filters(
        count_stmt, MediaTitle, updated_since=updated_since
    )
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.order_by(MediaTitle.created_at.desc()).limit(limit).offset(offset)
    )
    return list(result.scalars().all()), total


async def delete_media_title(
    session: AsyncSession, user: User, media_title_id: int
) -> None:
    media_title = await get_media_title(session, user, media_title_id)
    await soft_delete(media_title)
