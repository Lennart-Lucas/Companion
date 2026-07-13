from datetime import datetime
from decimal import Decimal
from typing import Self

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.goal import GoalDirection, GoalType
from app.scheduling.rrule_codec import is_recurring
from app.schemas.goal_milestone import MilestoneCreate, MilestoneResponse
from app.services.goal_milestone_validation import validate_milestones
from app.schemas.productivity_common import (
    ProductivityListResponse,
    validate_color_optional,
    validate_name,
)
from app.schemas.schedule import ScheduleCreate


class GoalCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    start_date: datetime
    end_date: datetime | None = None
    goal_type: GoalType
    target: Decimal = Field(gt=0)
    unit: str = Field(min_length=1, max_length=64)
    direction: GoalDirection
    milestones: list[MilestoneCreate] = Field(default_factory=list)

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
    def strip_unit(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("unit cannot be empty")
        return stripped

    @model_validator(mode="after")
    def validate_schedule_and_dates(self) -> Self:
        if self.schedule_id is None and self.schedule is None:
            raise ValueError("goal requires schedule_id or schedule")
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("goal cannot have both schedule_id and schedule")
        if self.schedule is not None and not is_recurring(
            self.schedule.rrule,
            self.schedule.rdates,
            quota_times=self.schedule.quota_times,
            quota_period_weeks=self.schedule.quota_period_weeks,
        ):
            raise ValueError("goal schedule must be recurring")
        if self.end_date is not None and self.end_date <= self.start_date:
            raise ValueError("end_date must be after start_date")
        if self.milestones:
            validate_milestones(self.target, self.direction, self.milestones)
        return self


class GoalUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    goal_type: GoalType | None = None
    target: Decimal | None = Field(default=None, gt=0)
    unit: str | None = Field(default=None, min_length=1, max_length=64)
    direction: GoalDirection | None = None

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
        if not stripped:
            raise ValueError("unit cannot be empty")
        return stripped

    @model_validator(mode="after")
    def validate_schedule_sources(self) -> Self:
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("goal cannot have both schedule_id and schedule")
        if self.schedule is not None and not is_recurring(
            self.schedule.rrule,
            self.schedule.rdates,
            quota_times=self.schedule.quota_times,
            quota_period_weeks=self.schedule.quota_period_weeks,
        ):
            raise ValueError("goal schedule must be recurring")
        return self


class GoalResponse(BaseModel):
    id: int
    name: str
    description: str | None
    icon: str | None
    color: str | None
    schedule_id: int
    start_date: datetime
    end_date: datetime | None
    goal_type: GoalType
    target: Decimal
    unit: str
    direction: GoalDirection
    milestones: list[MilestoneResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class GoalListResponse(ProductivityListResponse):
    items: list[GoalResponse]
