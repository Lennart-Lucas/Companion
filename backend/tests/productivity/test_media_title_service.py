from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from app.models.media_title import WATCH_STATUS_WATCHING, MediaTitle
from app.schemas.imdb import ImdbTitleDetailResponse
from app.schemas.media_title import MediaTitleCreate
from app.services import media_title_service


def _sample_detail() -> ImdbTitleDetailResponse:
    return ImdbTitleDetailResponse(
        imdb_id="tt1375666",
        name="Inception",
        media_type="movie",
        year=2010,
        description="A thief who steals secrets through dreams.",
        poster_url="https://example.com/inception.jpg",
        imdb_url="https://www.imdb.com/title/tt1375666/",
        rating=8.8,
        vote_count=2500000,
        genres=["Action", "Sci-Fi"],
        runtime_minutes=148,
        cast=[{"name": "Leonardo DiCaprio", "character": "Cobb"}],
    )


@pytest.mark.asyncio
async def test_create_media_title_persists_imdb_payload():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    user = SimpleNamespace(id=1)

    with patch(
        "app.services.media_title_service.imdb_api_client.get_title",
        new=AsyncMock(return_value=_sample_detail()),
    ), patch(
        "app.services.media_title_service._find_by_imdb_id",
        new=AsyncMock(return_value=None),
    ), patch(
        "app.services.media_title_service._find_deleted_by_imdb_id",
        new=AsyncMock(return_value=None),
    ):
        created = await media_title_service.create_media_title(
            session,
            user,
            MediaTitleCreate(imdb_id="tt1375666"),
        )

    assert created.name == "Inception"
    assert created.imdb_id == "tt1375666"
    session.add.assert_called_once()


@pytest.mark.asyncio
async def test_create_media_title_rejects_duplicate_imdb_id():
    session = AsyncMock()
    user = SimpleNamespace(id=1)
    existing = MediaTitle(
        id=7,
        user_id=1,
        imdb_id="tt1375666",
        name="Inception",
        imdb_url="https://www.imdb.com/title/tt1375666/",
    )

    with patch(
        "app.services.media_title_service.imdb_api_client.get_title",
        new=AsyncMock(return_value=_sample_detail()),
    ), patch(
        "app.services.media_title_service._find_by_imdb_id",
        new=AsyncMock(return_value=existing),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await media_title_service.create_media_title(
                session,
                user,
                MediaTitleCreate(imdb_id="tt1375666"),
            )

    assert exc_info.value.status_code == 409
    session.add.assert_not_called()


@pytest.mark.asyncio
async def test_create_media_title_restores_soft_deleted_title():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    user = SimpleNamespace(id=1)
    deleted = MediaTitle(
        id=7,
        user_id=1,
        imdb_id="tt1375666",
        name="Old Inception",
        imdb_url="https://www.imdb.com/title/tt1375666/",
        deleted_at=datetime.now(UTC),
    )
    cleared = AsyncMock()

    with patch(
        "app.services.media_title_service.imdb_api_client.get_title",
        new=AsyncMock(return_value=_sample_detail()),
    ), patch(
        "app.services.media_title_service._find_by_imdb_id",
        new=AsyncMock(return_value=None),
    ), patch(
        "app.services.media_title_service._find_deleted_by_imdb_id",
        new=AsyncMock(return_value=deleted),
    ), patch(
        "app.services.media_title_service._clear_watch_entries",
        new=cleared,
    ):
        restored = await media_title_service.create_media_title(
            session,
            user,
            MediaTitleCreate(imdb_id="tt1375666"),
        )

    assert restored is deleted
    assert restored.deleted_at is None
    assert restored.name == "Inception"
    session.add.assert_not_called()
    cleared.assert_awaited_once()


def _tv_detail() -> ImdbTitleDetailResponse:
    return ImdbTitleDetailResponse(
        imdb_id="tt0844441",
        name="True Blood",
        media_type="tvSeries",
        year=2008,
        description="Updated synopsis.",
        poster_url="https://example.com/true-blood.jpg",
        imdb_url="https://www.imdb.com/title/tt0844441/",
        rating=7.9,
        vote_count=250000,
        genres=["Drama", "Fantasy"],
        runtime_minutes=58,
        cast=[{"name": "Anna Paquin", "character": "Sookie Stackhouse"}],
    )


@pytest.mark.asyncio
async def test_refresh_media_title_updates_snapshot():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    user = SimpleNamespace(id=1)
    media_title = MediaTitle(
        id=3,
        user_id=1,
        imdb_id="tt0844441",
        name="Old True Blood",
        media_type="tvSeries",
        imdb_url="https://www.imdb.com/title/tt0844441/",
        description="Old plot",
        rating=7.0,
    )

    with patch(
        "app.services.media_title_service._load_media_title",
        new=AsyncMock(return_value=media_title),
    ), patch(
        "app.services.media_title_service.imdb_api_client.get_title",
        new=AsyncMock(return_value=_tv_detail()),
    ):
        refreshed = await media_title_service.refresh_media_title_from_imdb(
            session, user, 3
        )

    assert refreshed.name == "True Blood"
    assert refreshed.description == "Updated synopsis."
    assert refreshed.rating == 7.9


@pytest.mark.asyncio
async def test_refresh_media_title_preserves_watch_fields():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.refresh = AsyncMock()
    user = SimpleNamespace(id=1)
    media_title = MediaTitle(
        id=3,
        user_id=1,
        imdb_id="tt0844441",
        name="True Blood",
        media_type="tvSeries",
        imdb_url="https://www.imdb.com/title/tt0844441/",
        watch_status=WATCH_STATUS_WATCHING,
        user_rating=4.5,
        notes="Great rewatch",
    )

    with patch(
        "app.services.media_title_service._load_media_title",
        new=AsyncMock(return_value=media_title),
    ), patch(
        "app.services.media_title_service.imdb_api_client.get_title",
        new=AsyncMock(return_value=_tv_detail()),
    ):
        refreshed = await media_title_service.refresh_media_title_from_imdb(
            session, user, 3
        )

    assert refreshed.watch_status == WATCH_STATUS_WATCHING
    assert float(refreshed.user_rating) == 4.5
    assert refreshed.notes == "Great rewatch"
    assert refreshed.name == "True Blood"
