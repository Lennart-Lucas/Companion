from __future__ import annotations

import re
from typing import Any

import httpx
from fastapi import HTTPException, status

from app.schemas.imdb import ImdbTitleDetailResponse, ImdbTitleSummary

IMDB_API_BASE_URL = "https://imdbapi.dev"
IMDB_ID_PATTERN = re.compile(r"^tt\d{7,}$", re.IGNORECASE)
REQUEST_TIMEOUT = httpx.Timeout(15.0, connect=5.0)


def normalize_imdb_id(value: str) -> str:
    normalized = value.strip().lower()
    if not IMDB_ID_PATTERN.match(normalized):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="imdb_id must match tt followed by at least 7 digits",
        )
    return normalized


def imdb_page_url(imdb_id: str) -> str:
    return f"https://www.imdb.com/title/{imdb_id}/"


def _text_value(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        stripped = value.strip()
        return stripped or None
    if isinstance(value, dict):
        for key in ("text", "original", "plainText"):
            nested = value.get(key)
            if isinstance(nested, str) and nested.strip():
                return nested.strip()
    return None


def _image_url(value: Any) -> str | None:
    if isinstance(value, dict):
        url = value.get("url")
        if isinstance(url, str) and url.strip():
            return url.strip()
    return None


def _year_from_payload(payload: dict[str, Any]) -> int | None:
    for key in ("startYear", "year", "releaseYear"):
        year = payload.get(key)
        if isinstance(year, int) and year > 0:
            return year
    release_date = payload.get("releaseDate")
    if isinstance(release_date, dict):
        year = release_date.get("year")
        if isinstance(year, int) and year > 0:
            return year
    return None


def _media_type_from_payload(payload: dict[str, Any]) -> str | None:
    for key in ("titleType", "type", "types"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
        if isinstance(value, list) and value:
            first = value[0]
            if isinstance(first, str) and first.strip():
                return first.strip()
    return None


def _title_name_from_payload(payload: dict[str, Any]) -> str | None:
    for key in ("primaryTitle", "title", "name"):
        text = _text_value(payload.get(key))
        if text:
            return text
    for key in ("titleText", "originalTitleText", "originalTitle"):
        text = _text_value(payload.get(key))
        if text:
            return text
    return None


def _imdb_id_from_payload(payload: dict[str, Any]) -> str | None:
    for key in ("id", "titleId", "imdb_id"):
        value = payload.get(key)
        if isinstance(value, str) and IMDB_ID_PATTERN.match(value.strip()):
            return value.strip().lower()
    return None


def _rating_from_payload(payload: dict[str, Any]) -> tuple[float | None, int | None]:
    ratings = payload.get("ratings")
    if not isinstance(ratings, dict):
        return None, None
    rating = ratings.get("aggregateRating")
    if rating is None:
        rating = ratings.get("rating")
    vote_count = ratings.get("voteCount")
    if vote_count is None:
        vote_count = ratings.get("ratingCount")
    parsed_rating = float(rating) if rating is not None else None
    parsed_votes = int(vote_count) if vote_count is not None else None
    return parsed_rating, parsed_votes


def _genres_from_payload(payload: dict[str, Any]) -> list[str]:
    genres = payload.get("genres")
    if not isinstance(genres, list):
        return []
    result: list[str] = []
    for entry in genres:
        if isinstance(entry, str) and entry.strip():
            result.append(entry.strip())
            continue
        if isinstance(entry, dict):
            text = _text_value(entry.get("text")) or _text_value(entry.get("genre"))
            if text:
                result.append(text)
    return result


def _runtime_minutes_from_payload(payload: dict[str, Any]) -> int | None:
    runtime_seconds = payload.get("runtimeSeconds")
    if isinstance(runtime_seconds, int) and runtime_seconds > 0:
        return max(1, runtime_seconds // 60)
    runtime = payload.get("runtime")
    if isinstance(runtime, dict):
        seconds = runtime.get("seconds")
        if isinstance(seconds, int) and seconds > 0:
            return max(1, seconds // 60)
    return None


def _plot_from_payload(payload: dict[str, Any]) -> str | None:
    for key in ("plot", "plotText", "description"):
        text = _text_value(payload.get(key))
        if text:
            return text
    plot = payload.get("plot")
    if isinstance(plot, dict):
        return _text_value(plot)
    return None


def _cast_from_payload(payload: dict[str, Any]) -> list[dict]:
    cast_entries = payload.get("principalCast")
    if not isinstance(cast_entries, list):
        cast_entries = payload.get("cast")
    if not isinstance(cast_entries, list):
        return []

    cast: list[dict] = []
    for entry in cast_entries[:12]:
        if not isinstance(entry, dict):
            continue
        name_block = entry.get("name")
        actor_name = None
        if isinstance(name_block, dict):
            actor_name = _text_value(name_block.get("nameText")) or _text_value(
                name_block.get("name")
            )
        characters = entry.get("characters")
        character = None
        if isinstance(characters, list) and characters:
            first = characters[0]
            character = first if isinstance(first, str) else _text_value(first)
        if actor_name:
            cast.append({"name": actor_name, "character": character})
    return cast


def _summary_from_payload(payload: dict[str, Any]) -> ImdbTitleSummary | None:
    imdb_id = _imdb_id_from_payload(payload)
    name = _title_name_from_payload(payload)
    if imdb_id is None or name is None:
        return None
    return ImdbTitleSummary(
        imdb_id=imdb_id,
        name=name,
        media_type=_media_type_from_payload(payload),
        year=_year_from_payload(payload),
        poster_url=_image_url(payload.get("primaryImage")),
    )


def _detail_from_payload(payload: dict[str, Any]) -> ImdbTitleDetailResponse:
    summary = _summary_from_payload(payload)
    if summary is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="IMDb API returned an invalid title payload",
        )
    rating, vote_count = _rating_from_payload(payload)
    return ImdbTitleDetailResponse(
        imdb_id=summary.imdb_id,
        name=summary.name,
        media_type=summary.media_type,
        year=summary.year,
        description=_plot_from_payload(payload),
        poster_url=summary.poster_url,
        imdb_url=imdb_page_url(summary.imdb_id),
        rating=rating,
        vote_count=vote_count,
        genres=_genres_from_payload(payload),
        runtime_minutes=_runtime_minutes_from_payload(payload),
        cast=_cast_from_payload(payload),
    )


def _titles_from_search_payload(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict):
        for key in ("titles", "results", "items"):
            entries = payload.get(key)
            if isinstance(entries, list):
                return [entry for entry in entries if isinstance(entry, dict)]
        if _imdb_id_from_payload(payload):
            return [payload]
    if isinstance(payload, list):
        return [entry for entry in payload if isinstance(entry, dict)]
    return []


class ImdbApiClient:
    def __init__(self, base_url: str = IMDB_API_BASE_URL) -> None:
        self._base_url = base_url.rstrip("/")

    async def search_titles(
        self, query: str, *, limit: int = 20
    ) -> list[ImdbTitleSummary]:
        trimmed = query.strip()
        if not trimmed:
            return []

        params = {"query": trimmed, "limit": min(max(limit, 1), 50)}
        payload = await self._get("/search/titles", params=params)
        summaries: list[ImdbTitleSummary] = []
        seen: set[str] = set()
        for entry in _titles_from_search_payload(payload):
            summary = _summary_from_payload(entry)
            if summary is None or summary.imdb_id in seen:
                continue
            seen.add(summary.imdb_id)
            summaries.append(summary)
        return summaries

    async def get_title(self, imdb_id: str) -> ImdbTitleDetailResponse:
        normalized = normalize_imdb_id(imdb_id)
        payload = await self._get(f"/titles/{normalized}")
        if isinstance(payload, dict) and isinstance(payload.get("title"), dict):
            payload = payload["title"]
        if not isinstance(payload, dict):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Title not found on IMDb",
            )
        detail = _detail_from_payload(payload)
        if detail.imdb_id != normalized and _imdb_id_from_payload(payload) is None:
            detail = detail.model_copy(update={"imdb_id": normalized})
        return detail

    async def _get(self, path: str, *, params: dict[str, Any] | None = None) -> Any:
        url = f"{self._base_url}{path}"
        try:
            async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
                response = await client.get(url, params=params)
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"IMDb API request failed: {exc}",
            ) from exc

        if response.status_code == status.HTTP_404_NOT_FOUND:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Title not found on IMDb",
            )
        if response.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"IMDb API error ({response.status_code})",
            )
        try:
            return response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="IMDb API returned invalid JSON",
            ) from exc


imdb_api_client = ImdbApiClient()
