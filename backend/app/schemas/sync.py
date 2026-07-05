from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class SyncChangesResponse(BaseModel):
    since: datetime | None = None
    server_time: datetime
    upserts: dict[str, list[dict[str, Any]]] = Field(default_factory=dict)
    tombstones: dict[str, list[str]] = Field(default_factory=dict)
