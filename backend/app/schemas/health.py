from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    imdb_api_base: str


class DbHealthResponse(BaseModel):
    status: str
    database: str
