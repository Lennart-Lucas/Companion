from app.services.imdb_api_client import (
    _cast_from_payload,
    _detail_from_payload,
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
