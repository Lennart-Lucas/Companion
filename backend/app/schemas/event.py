from datetime import datetime
from typing import Self

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.productivity_common import (
    ProductivityListResponse,
    validate_color_optional,
    validate_name,
)
from app.schemas.schedule import ScheduleCreate


class EventCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    start_at: datetime
    end_at: datetime | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return validate_name(v)

    @field_validator("color")
    @classmethod
    def check_color(cls, v: str | None) -> str | None:
        return validate_color_optional(v)

    @model_validator(mode="after")
    def validate_schedule_and_time_range(self) -> Self:
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("event cannot have both schedule_id and schedule")
        if self.end_at is not None and self.end_at <= self.start_at:
            raise ValueError("end_at must be after start_at")
        return self


class EventUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    start_at: datetime | None = None
    end_at: datetime | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str | None) -> str | None:
        if v is None:
            return v
        return validate_name(v)

    @field_validator("color")
    @classmethod
    def check_color(cls, v: str | None) -> str | None:
        return validate_color_optional(v)

    @model_validator(mode="after")
    def validate_schedule_exclusivity(self) -> Self:
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("event cannot have both schedule_id and schedule")
        return self


class EventResponse(BaseModel):
    id: int
    name: str
    description: str | None
    icon: str | None
    color: str | None
    start_at: datetime
    end_at: datetime | None
    schedule_id: int | None
    is_recurring: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class EventListResponse(ProductivityListResponse):
    items: list[EventResponse]
