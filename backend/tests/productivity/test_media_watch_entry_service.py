from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.models.media_title import WATCH_STATUS_PLAN_TO_WATCH, WATCH_STATUS_WATCHING, MediaTitle
from app.schemas.media_watch_entry import MediaWatchEntryCreate
from app.schemas.media_title import MediaTitleUpdate
from app.services import media_title_service, media_watch_entry_service


def _mock_session_with_no_existing_entry():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    session.execute = AsyncMock(return_value=result)
    return session


@pytest.mark.asyncio
async def test_create_movie_watch_entry():
    session = _mock_session_with_no_existing_entry()
    user = SimpleNamespace(id=1)
    media_title = MediaTitle(
        id=3,
        user_id=1,
        imdb_id="tt1375666",
        name="Inception",
        media_type="movie",
        imdb_url="https://www.imdb.com/title/tt1375666/",
        watch_status=WATCH_STATUS_PLAN_TO_WATCH,
    )

    with patch(
        "app.services.media_watch_entry_service._load_media_title",
        new=AsyncMock(return_value=media_title),
    ):
        entry = await media_watch_entry_service.create_watch_entry(
            session,
            user,
            3,
            MediaWatchEntryCreate(),
        )

    assert entry.media_title_id == 3
    assert entry.season_number is None
    assert media_title.watch_status == WATCH_STATUS_WATCHING


@pytest.mark.asyncio
async def test_create_tv_watch_entry_requires_season_episode():
    session = AsyncMock()
    user = SimpleNamespace(id=1)
    media_title = MediaTitle(
        id=3,
        user_id=1,
        imdb_id="tt0844441",
        name="True Blood",
        media_type="tvSeries",
        imdb_url="https://www.imdb.com/title/tt0844441/",
    )

    with patch(
        "app.services.media_watch_entry_service._load_media_title",
        new=AsyncMock(return_value=media_title),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await media_watch_entry_service.create_watch_entry(
                session,
                user,
                3,
                MediaWatchEntryCreate(),
            )

    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_update_media_title_watch_fields():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    user = SimpleNamespace(id=1)
    media_title = MediaTitle(
        id=3,
        user_id=1,
        imdb_id="tt1375666",
        name="Inception",
        media_type="movie",
        imdb_url="https://www.imdb.com/title/tt1375666/",
        watch_status=WATCH_STATUS_PLAN_TO_WATCH,
    )

    with patch(
        "app.services.media_title_service._load_media_title",
        new=AsyncMock(return_value=media_title),
    ):
        updated = await media_title_service.update_media_title(
            session,
            user,
            3,
            MediaTitleUpdate(watch_status=WATCH_STATUS_WATCHING, user_rating=4.5),
        )

    assert updated.watch_status == WATCH_STATUS_WATCHING
    assert float(updated.user_rating) == 4.5
