from unittest.mock import AsyncMock, patch

import pytest

from app.schemas.imdb import ImdbTitleSummary
from app.services.imdb_api_client import (
    IMDB_API_BASE_URL,
    ImdbApiClient,
    _cast_from_payload,
    _detail_from_payload,
    _episode_from_payload,
    _genres_from_payload,
    _summary_from_payload,
    imdb_page_url,
    normalize_imdb_id,
)


class TestImdbIdNormalization:
    def test_normalize_imdb_id_lowercases(self):
        assert normalize_imdb_id("TT1375666") == "tt1375666"

    def test_imdb_page_url(self):
        assert imdb_page_url("tt1375666") == "https://www.imdb.com/title/tt1375666/"


class TestImdbPayloadMapping:
    def test_summary_from_search_style_payload(self):
        summary = _summary_from_payload(
            {
                "id": "tt1375666",
                "primaryTitle": "Inception",
                "type": "movie",
                "startYear": 2010,
                "primaryImage": {"url": "https://example.com/inception.jpg"},
            }
        )
        assert summary is not None
        assert summary.imdb_id == "tt1375666"
        assert summary.name == "Inception"
        assert summary.year == 2010
        assert summary.poster_url == "https://example.com/inception.jpg"

    def test_detail_from_title_payload(self):
        detail = _detail_from_payload(
            {
                "id": "tt1375666",
                "titleText": {"text": "Inception"},
                "titleType": "movie",
                "releaseDate": {"year": 2010},
                "primaryImage": {"url": "https://example.com/inception.jpg"},
                "ratings": {"aggregateRating": 8.8, "voteCount": 2500000},
                "genres": [{"text": "Action"}, {"text": "Sci-Fi"}],
                "runtimeSeconds": 8880,
                "plot": "A thief who steals secrets through dreams.",
                "principalCast": [
                    {
                        "name": {"nameText": {"text": "Leonardo DiCaprio"}},
                        "characters": ["Cobb"],
                    }
                ],
            }
        )
        assert detail.imdb_id == "tt1375666"
        assert detail.name == "Inception"
        assert detail.year == 2010
        assert detail.rating == 8.8
        assert detail.vote_count == 2500000
        assert detail.genres == ["Action", "Sci-Fi"]
        assert detail.runtime_minutes == 148
        assert detail.cast == [{"name": "Leonardo DiCaprio", "character": "Cobb"}]
        assert detail.imdb_url == imdb_page_url("tt1375666")

    def test_genres_from_string_list(self):
        assert _genres_from_payload({"genres": ["Drama", "Crime"]}) == [
            "Drama",
            "Crime",
        ]

    def test_cast_limits_to_twelve_entries(self):
        cast = _cast_from_payload(
            {
                "principalCast": [
                    {
                        "name": {"nameText": {"text": f"Actor {index}"}},
                        "characters": [f"Role {index}"],
                    }
                    for index in range(20)
                ]
            }
        )
        assert len(cast) == 12

    def test_episode_from_payload(self):
        episode = _episode_from_payload(
            {
                "id": "tt1008582",
                "title": "Strange Love",
                "season": "1",
                "episodeNumber": 1,
                "runtimeSeconds": 3480,
                "releaseDate": {"year": 2008, "month": 9, "day": 7},
                "rating": {"aggregateRating": 7.8},
            }
        )
        assert episode is not None
        assert episode.imdb_id == "tt1008582"
        assert episode.season_number == 1
        assert episode.episode_number == 1
        assert episode.runtime_minutes == 58


class TestImdbApiClient:
    def test_default_base_url_uses_api_subdomain(self):
        assert IMDB_API_BASE_URL == "https://api.imdbapi.dev"

    @pytest.mark.asyncio
    async def test_search_prefers_suggestion_results(self):
        client = ImdbApiClient()
        expected = [
            ImdbTitleSummary(
                imdb_id="tt0844441",
                name="True Blood",
                media_type="tvSeries",
                year=2008,
                poster_url="https://example.com/true-blood.jpg",
            )
        ]

        with patch.object(
            client, "_search_via_suggestion", AsyncMock(return_value=expected)
        ):
            with patch.object(client, "_get", AsyncMock()) as mock_get:
                results = await client.search_titles("true blood")

        assert results == expected
        mock_get.assert_not_called()

    @pytest.mark.asyncio
    async def test_search_falls_back_to_api_when_suggestion_empty(self):
        client = ImdbApiClient()
        api_payload = {
            "titles": [
                {
                    "id": "tt0844441",
                    "primaryTitle": "True Blood",
                    "type": "tvSeries",
                    "startYear": 2008,
                }
            ]
        }

        with patch.object(client, "_search_via_suggestion", AsyncMock(return_value=[])):
            with patch.object(client, "_get", AsyncMock(return_value=api_payload)):
                results = await client.search_titles("true blood")

        assert len(results) == 1
        assert results[0].imdb_id == "tt0844441"
        assert results[0].name == "True Blood"
