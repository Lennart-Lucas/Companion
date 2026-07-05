from datetime import date, datetime
from typing import Self

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.schedule_override import OverrideScope as ModelOverrideScope


class ScheduleCreate(BaseModel):
    dtstart: datetime
    timezone: str = Field(min_length=1, max_length=64)
    rrule: str | None = None
    rdates: list[date] | None = None
    exdates: list[date] | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None

    @field_validator("rdates", "exdates")
    @classmethod
    def sort_unique_dates(cls, v: list[date] | None) -> list[date] | None:
        if v is None:
            return v
        return sorted(set(v))

    @model_validator(mode="after")
    def validate_date_range(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date <= self.start_date
        ):
            raise ValueError("end_date must be after start_date")
        return self


class ScheduleUpdate(BaseModel):
    dtstart: datetime | None = None
    timezone: str | None = Field(default=None, min_length=1, max_length=64)
    rrule: str | None = None
    rdates: list[date] | None = None
    exdates: list[date] | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    truncate_before_occurrence_at: datetime | None = None

    @field_validator("rdates", "exdates")
    @classmethod
    def sort_unique_dates(cls, v: list[date] | None) -> list[date] | None:
        if v is None:
            return v
        return sorted(set(v))

    @model_validator(mode="after")
    def validate_date_range(self) -> Self:
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date <= self.start_date
        ):
            raise ValueError("end_date must be after start_date")
        return self


class ScheduleRdateResponse(BaseModel):
    id: int
    occurrence_date: date

    model_config = {"from_attributes": True}


class ScheduleExdateResponse(BaseModel):
    id: int
    excluded_date: date

    model_config = {"from_attributes": True}


class ScheduleOverrideResponse(BaseModel):
    id: int
    scope: ModelOverrideScope
    effective_at: datetime
    replacement_schedule_id: int

    model_config = {"from_attributes": True}


class ScheduleResponse(BaseModel):
    id: int
    dtstart: datetime
    rrule: str | None
    start_date: datetime | None
    end_date: datetime | None
    timezone: str
    rdates: list[ScheduleRdateResponse] = []
    exdates: list[ScheduleExdateResponse] = []
    overrides: list[ScheduleOverrideResponse] = []
    is_recurring: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ScheduleListResponse(BaseModel):
    items: list[ScheduleResponse]
    total: int
    limit: int
    offset: int


class SchedulePreviewRequest(BaseModel):
    from_: datetime = Field(alias="from")
    to: datetime
    max_count: int = Field(default=500, ge=1, le=5000)

    model_config = {"populate_by_name": True}


class SchedulePreviewResponse(BaseModel):
    occurrences: list[datetime]


class RdatesReplace(BaseModel):
    dates: list[date] = Field(min_length=1)


class ExdatesReplace(BaseModel):
    dates: list[date] = Field(default_factory=list)


class OccurrenceExclusionCreate(BaseModel):
    occurrence_at: datetime


class ScheduleOverrideCreate(BaseModel):
    scope: ModelOverrideScope
    effective_at: datetime
    replacement_schedule_id: int


# Backward-compatible aliases for routes still named specific-dates / exclusions.
SpecificDatesReplace = RdatesReplace
ExclusionsReplace = ExdatesReplace
