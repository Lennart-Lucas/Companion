import re
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.media_title import WATCH_STATUSES
from app.schemas.productivity_common import ProductivityListResponse

IMDB_ID_PATTERN = re.compile(r"^tt\d{7,}$", re.IGNORECASE)


class MediaTitleCreate(BaseModel):
    imdb_id: str = Field(min_length=9, max_length=16)

    @field_validator("imdb_id")
    @classmethod
    def validate_imdb_id(cls, value: str) -> str:
        normalized = value.strip()
        if not IMDB_ID_PATTERN.match(normalized):
            raise ValueError("imdb_id must match tt followed by at least 7 digits")
        return normalized.lower()


class MediaTitleUpdate(BaseModel):
    watch_status: str | None = None
    user_rating: float | None = Field(default=None, ge=0.5, le=5.0)
    notes: str | None = None

    @field_validator("watch_status")
    @classmethod
    def validate_watch_status(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if normalized not in WATCH_STATUSES:
            raise ValueError(
                f"watch_status must be one of: {', '.join(sorted(WATCH_STATUSES))}"
            )
        return normalized

    @field_validator("user_rating")
    @classmethod
    def validate_user_rating_step(cls, value: float | None) -> float | None:
        if value is None:
            return None
        doubled = round(value * 2)
        if abs(value * 2 - doubled) > 1e-6:
            raise ValueError("user_rating must be in 0.5 increments")
        return round(value, 1)

    @field_validator("notes")
    @classmethod
    def normalize_notes(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        return trimmed or None


class MediaTitleResponse(BaseModel):
    id: int
    imdb_id: str
    name: str
    media_type: str | None
    year: int | None
    description: str | None
    poster_url: str | None
    imdb_url: str
    rating: float | None
    vote_count: int | None
    genres: list[str] | None
    runtime_minutes: int | None
    cast: list[dict] | None
    watch_status: str
    user_rating: float | None
    notes: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MediaTitleListResponse(ProductivityListResponse):
    items: list[MediaTitleResponse]
