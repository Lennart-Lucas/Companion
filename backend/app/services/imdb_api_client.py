from __future__ import annotations

import json
import re
import time
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx
from fastapi import HTTPException, status

from app.schemas.imdb import ImdbTitleDetailResponse, ImdbTitleSummary

IMDB_API_BASE_URL = "https://api.imdbapi.dev"
IMDB_SUGGESTION_BASE_URL = "https://v3.sg.media-imdb.com/suggestion/x"
IMDB_ID_PATTERN = re.compile(r"^tt\d{7,}$", re.IGNORECASE)
REQUEST_TIMEOUT = httpx.Timeout(15.0, connect=5.0)
DEBUG_LOG_PATH = Path(__file__).resolve().parents[3] / "debug-0107d2.log"


def _agent_debug_log(
    hypothesis_id: str, location: str, message: str, data: dict[str, Any]
) -> None:
    # region agent log
    try:
        payload = {
            "sessionId": "0107d2",
            "hypothesisId": hypothesis_id,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": int(time.time() * 1000),
        }
        with DEBUG_LOG_PATH.open("a", encoding="utf-8") as log_file:
            log_file.write(json.dumps(payload) + "\n")
    except OSError:
        pass
    # endregion


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

        capped_limit = min(max(limit, 1), 50)
        params = {"query": trimmed, "limit": capped_limit}
        _agent_debug_log(
            "A",
            "imdb_api_client.py:search_titles",
            "search_start",
            {"base_url": self._base_url, "query": trimmed, "limit": capped_limit},
        )

        summaries: list[ImdbTitleSummary] = []
        primary_error: str | None = None
        try:
            payload = await self._get("/search/titles", params=params)
            summaries = self._summaries_from_entries(
                _titles_from_search_payload(payload), capped_limit
            )
            _agent_debug_log(
                "B",
                "imdb_api_client.py:search_titles",
                "primary_search_result",
                {"result_count": len(summaries)},
            )
        except HTTPException as exc:
            primary_error = str(exc.detail)
            _agent_debug_log(
                "B",
                "imdb_api_client.py:search_titles",
                "primary_search_failed",
                {"status_code": exc.status_code, "detail": primary_error},
            )

        if summaries:
            return summaries

        fallback = await self._search_via_suggestion(trimmed, limit=capped_limit)
        _agent_debug_log(
            "C",
            "imdb_api_client.py:search_titles",
            "suggestion_fallback_result",
            {
                "result_count": len(fallback),
                "primary_error": primary_error,
                "first_imdb_id": fallback[0].imdb_id if fallback else None,
            },
        )
        return fallback

    def _summaries_from_entries(
        self, entries: list[dict[str, Any]], limit: int
    ) -> list[ImdbTitleSummary]:
        summaries: list[ImdbTitleSummary] = []
        seen: set[str] = set()
        for entry in entries:
            summary = _summary_from_payload(entry)
            if summary is None or summary.imdb_id in seen:
                continue
            seen.add(summary.imdb_id)
            summaries.append(summary)
            if len(summaries) >= limit:
                break
        return summaries

    async def _search_via_suggestion(
        self, query: str, *, limit: int
    ) -> list[ImdbTitleSummary]:
        url = f"{IMDB_SUGGESTION_BASE_URL}/{quote(query.strip().lower())}.json"
        try:
            async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
                response = await client.get(url)
        except httpx.RequestError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"IMDb suggestion request failed: {exc}",
            ) from exc

        if response.status_code >= 400:
            return []

        try:
            payload = response.json()
        except ValueError:
            return []

        entries = payload.get("d") if isinstance(payload, dict) else None
        if not isinstance(entries, list):
            return []

        summaries: list[ImdbTitleSummary] = []
        seen: set[str] = set()
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            imdb_id = entry.get("id")
            name = entry.get("l")
            if not isinstance(imdb_id, str) or not isinstance(name, str):
                continue
            normalized_id = imdb_id.strip().lower()
            if not IMDB_ID_PATTERN.match(normalized_id) or normalized_id in seen:
                continue
            seen.add(normalized_id)
            image = entry.get("i")
            poster_url = None
            if isinstance(image, dict):
                raw_poster = image.get("imageUrl")
                if isinstance(raw_poster, str) and raw_poster.strip():
                    poster_url = raw_poster.strip()
            year = entry.get("y")
            media_type = entry.get("qid") or entry.get("q")
            summaries.append(
                ImdbTitleSummary(
                    imdb_id=normalized_id,
                    name=name.strip(),
                    media_type=media_type if isinstance(media_type, str) else None,
                    year=year if isinstance(year, int) else None,
                    poster_url=poster_url,
                )
            )
            if len(summaries) >= limit:
                break
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
        _agent_debug_log(
            "A",
            "imdb_api_client.py:_get",
            "request_start",
            {"url": url, "params": params or {}},
        )
        try:
            async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
                response = await client.get(url, params=params)
        except httpx.RequestError as exc:
            _agent_debug_log(
                "D",
                "imdb_api_client.py:_get",
                "request_error",
                {"url": url, "error": str(exc)},
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"IMDb API request failed: {exc}",
            ) from exc

        _agent_debug_log(
            "A",
            "imdb_api_client.py:_get",
            "response_received",
            {
                "url": url,
                "status_code": response.status_code,
                "content_type": response.headers.get("content-type"),
            },
        )

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
