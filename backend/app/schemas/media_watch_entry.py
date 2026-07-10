from datetime import datetime

from pydantic import BaseModel, Field


class MediaWatchEntryCreate(BaseModel):
    season_number: int | None = Field(default=None, ge=1)
    episode_number: int | None = Field(default=None, ge=1)
    episode_imdb_id: str | None = Field(default=None, max_length=16)
    episode_title: str | None = Field(default=None, max_length=255)
    watched_at: datetime | None = None


class MediaWatchEntryResponse(BaseModel):
    id: int
    media_title_id: int
    season_number: int | None
    episode_number: int | None
    episode_imdb_id: str | None
    episode_title: str | None
    watched_at: datetime
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MediaWatchEntryListResponse(BaseModel):
    items: list[MediaWatchEntryResponse]
