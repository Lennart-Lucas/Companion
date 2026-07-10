import re
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

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
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MediaTitleListResponse(ProductivityListResponse):
    items: list[MediaTitleResponse]
