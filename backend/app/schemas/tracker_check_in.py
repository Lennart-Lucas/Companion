from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator

from app.models.tracker import CheckInType


class TrackerCheckInResponse(BaseModel):
    id: int
    check_in_at: datetime
    display_at: datetime
    check_in_type: CheckInType
    completed: bool | None = None
    count_value: Decimal | None = None
    value_seconds: int | None = None
    timer_started_at: datetime | None = None
    skipped: bool = False
    logged: bool
    period_start_at: datetime | None = None
    slot_index: int | None = None
    slot_kind: str | None = None
    failed: bool = False

    model_config = {"from_attributes": True}


class TrackerCheckInListResponse(BaseModel):
    items: list[TrackerCheckInResponse]


class TrackerCheckInUpdate(BaseModel):
    completed: bool | None = None
    count_value: Decimal | None = Field(default=None, ge=0)
    value_seconds: int | None = Field(default=None, ge=0)
    timer_started_at: datetime | None = None
    skipped: bool | None = None

    @model_validator(mode="after")
    def validate_single_field(self) -> "TrackerCheckInUpdate":
        set_fields = [
            name
            for name in (
                "completed",
                "count_value",
                "value_seconds",
                "timer_started_at",
                "skipped",
            )
            if getattr(self, name) is not None
        ]
        if len(set_fields) != 1:
            raise ValueError(
                "exactly one of completed, count_value, value_seconds, "
                "timer_started_at, or skipped must be set"
            )
        if self.skipped is not None and self.skipped is not True:
            raise ValueError("skipped must be true when set")
        return self


class TrackerCheckInCreate(TrackerCheckInUpdate):
    check_in_at: datetime
