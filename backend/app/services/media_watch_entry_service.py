from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.media_title import (
    WATCH_STATUS_PLAN_TO_WATCH,
    WATCH_STATUS_WATCHING,
    MediaTitle,
)
from app.models.media_watch_entry import MediaWatchEntry
from app.models.user import User
from app.schemas.media_watch_entry import MediaWatchEntryCreate, MediaWatchEntryResponse
from app.services.media_title_service import _load_media_title
from app.services.productivity_helpers import soft_delete


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _is_tv_media_type(media_type: str | None) -> bool:
    if not media_type:
        return False
    normalized = media_type.strip().lower().replace("_", "")
    return normalized in {
        "tvseries",
        "tvminiseries",
        "tvspecial",
    }


async def list_watch_entries(
    session: AsyncSession, user: User, media_title_id: int
) -> list[MediaWatchEntry]:
    await _load_media_title(session, media_title_id, user.id)
    result = await session.execute(
        select(MediaWatchEntry)
        .where(
            MediaWatchEntry.media_title_id == media_title_id,
            MediaWatchEntry.deleted_at.is_(None),
        )
        .order_by(MediaWatchEntry.watched_at.desc(), MediaWatchEntry.id.desc())
    )
    return list(result.scalars().all())


async def create_watch_entry(
    session: AsyncSession,
    user: User,
    media_title_id: int,
    data: MediaWatchEntryCreate,
) -> MediaWatchEntry:
    media_title = await _load_media_title(session, media_title_id, user.id)
    is_tv = _is_tv_media_type(media_title.media_type)

    if is_tv:
        if data.season_number is None or data.episode_number is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="season_number and episode_number are required for TV titles",
            )
    elif data.season_number is not None or data.episode_number is not None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="season_number and episode_number must be omitted for movies",
        )

    season_number = data.season_number
    episode_number = data.episode_number

    existing = await session.execute(
        select(MediaWatchEntry).where(
            MediaWatchEntry.media_title_id == media_title_id,
            MediaWatchEntry.season_number.is_(None)
            if season_number is None
            else MediaWatchEntry.season_number == season_number,
            MediaWatchEntry.episode_number.is_(None)
            if episode_number is None
            else MediaWatchEntry.episode_number == episode_number,
            MediaWatchEntry.deleted_at.is_(None),
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This watch entry already exists",
        )

    watched_at = _ensure_utc(data.watched_at or datetime.now(UTC))
    entry = MediaWatchEntry(
        media_title_id=media_title_id,
        season_number=season_number,
        episode_number=episode_number,
        episode_imdb_id=data.episode_imdb_id,
        episode_title=data.episode_title,
        watched_at=watched_at,
    )
    session.add(entry)

    if media_title.watch_status == WATCH_STATUS_PLAN_TO_WATCH:
        media_title.watch_status = WATCH_STATUS_WATCHING

    await session.flush()
    await session.refresh(entry)
    return entry


async def delete_watch_entry(
    session: AsyncSession, user: User, media_title_id: int, entry_id: int
) -> None:
    await _load_media_title(session, media_title_id, user.id)
    result = await session.execute(
        select(MediaWatchEntry).where(
            MediaWatchEntry.id == entry_id,
            MediaWatchEntry.media_title_id == media_title_id,
            MediaWatchEntry.deleted_at.is_(None),
        )
    )
    entry = result.scalar_one_or_none()
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watch entry not found",
        )
    await soft_delete(entry)


def watch_entry_to_response(entry: MediaWatchEntry) -> MediaWatchEntryResponse:
    return MediaWatchEntryResponse.model_validate(entry)
