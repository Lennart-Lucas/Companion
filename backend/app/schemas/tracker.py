from datetime import datetime
from decimal import Decimal
from typing import Self

from pydantic import BaseModel, Field, field_validator, model_validator

from app.scheduling.rrule_codec import is_recurring
from app.models.tracker import CheckInType, HabitDirection
from app.schemas.productivity_common import (
    ProductivityListResponse,
    validate_color_optional,
    validate_name,
)
from app.schemas.schedule import ScheduleCreate


def validate_tracker_type_fields(
    check_in_type: CheckInType,
    *,
    target: Decimal | None,
    unit: str | None,
) -> None:
    if check_in_type == CheckInType.task:
        if target is not None or unit is not None:
            raise ValueError("task check-in type cannot have target or unit")
    elif check_in_type == CheckInType.count:
        if target is None or not unit:
            raise ValueError("count check-in type requires target and unit")
    elif check_in_type == CheckInType.duration:
        if target is None:
            raise ValueError("duration check-in type requires target (seconds)")
        if unit is not None:
            raise ValueError("duration check-in type cannot have unit")


class TrackerCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    goal_id: int | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    start_date: datetime
    end_date: datetime | None = None
    check_in_type: CheckInType
    target: Decimal | None = None
    unit: str | None = Field(default=None, max_length=64)
    habit_direction: HabitDirection

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return validate_name(v)

    @field_validator("color")
    @classmethod
    def check_color(cls, v: str | None) -> str | None:
        return validate_color_optional(v)

    @field_validator("unit")
    @classmethod
    def strip_unit(cls, v: str | None) -> str | None:
        if v is None:
            return v
        stripped = v.strip()
        return stripped if stripped else None

    @model_validator(mode="after")
    def validate_schedule_and_fields(self) -> Self:
        if self.schedule_id is None and self.schedule is None:
            raise ValueError("tracker requires schedule_id or schedule")
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("tracker cannot have both schedule_id and schedule")
        if self.schedule is not None and not is_recurring(
            self.schedule.rrule, self.schedule.rdates
        ):
            raise ValueError("tracker schedule must be recurring")
        if self.end_date is not None and self.end_date <= self.start_date:
            raise ValueError("end_date must be after start_date")
        validate_tracker_type_fields(
            self.check_in_type, target=self.target, unit=self.unit
        )
        return self


class TrackerUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    goal_id: int | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    check_in_type: CheckInType | None = None
    target: Decimal | None = None
    unit: str | None = Field(default=None, max_length=64)
    habit_direction: HabitDirection | None = None

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

    @field_validator("unit")
    @classmethod
    def strip_unit(cls, v: str | None) -> str | None:
        if v is None:
            return v
        stripped = v.strip()
        return stripped if stripped else None

    @model_validator(mode="after")
    def validate_schedule_sources(self) -> Self:
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("tracker cannot have both schedule_id and schedule")
        if self.schedule is not None and not is_recurring(
            self.schedule.rrule, self.schedule.rdates
        ):
            raise ValueError("tracker schedule must be recurring")
        return self


class TrackerResponse(BaseModel):
    id: int
    name: str
    description: str | None
    icon: str | None
    color: str | None
    goal_id: int | None
    schedule_id: int
    start_date: datetime
    end_date: datetime | None
    check_in_type: CheckInType
    target: Decimal | None
    unit: str | None
    habit_direction: HabitDirection
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TrackerListResponse(ProductivityListResponse):
    items: list[TrackerResponse]
