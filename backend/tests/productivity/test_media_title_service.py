from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from app.models.media_title import MediaTitle
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
