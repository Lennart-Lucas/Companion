from pydantic import BaseModel, Field


class ImdbTitleSummary(BaseModel):
    imdb_id: str
    name: str
    media_type: str | None = None
    year: int | None = None
    poster_url: str | None = None


class ImdbTitleSearchResponse(BaseModel):
    items: list[ImdbTitleSummary]


class ImdbTitleDetailResponse(BaseModel):
    imdb_id: str
    name: str
    media_type: str | None = None
    year: int | None = None
    description: str | None = None
    poster_url: str | None = None
    imdb_url: str
    rating: float | None = None
    vote_count: int | None = None
    genres: list[str] = Field(default_factory=list)
    runtime_minutes: int | None = None
    cast: list[dict] = Field(default_factory=list)


class ImdbEpisodeSummary(BaseModel):
    imdb_id: str
    title: str
    season_number: int
    episode_number: int
    runtime_minutes: int | None = None
    release_year: int | None = None
    release_month: int | None = None
    release_day: int | None = None
    rating: float | None = None


class ImdbEpisodeListResponse(BaseModel):
    items: list[ImdbEpisodeSummary]
    next_page_token: str | None = None
