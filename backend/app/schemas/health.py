from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str


class DbHealthResponse(BaseModel):
    status: str
    database: str
