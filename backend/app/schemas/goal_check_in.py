from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field, model_validator

from app.models.goal import GoalType


class GoalCheckInResponse(BaseModel):
    id: int
    check_in_at: datetime
    display_at: datetime
    goal_type: GoalType
    completed: bool | None = None
    count_value: Decimal | None = None
    pulse_score: int | None = None
    logged: bool
    period_start_at: datetime | None = None
    slot_index: int | None = None
    slot_kind: str | None = None
    failed: bool = False

    model_config = {"from_attributes": True}


class GoalCheckInListResponse(BaseModel):
    items: list[GoalCheckInResponse]


class GoalCheckInUpdate(BaseModel):
    completed: bool | None = None
    count_value: Decimal | None = Field(default=None, ge=0)

    @model_validator(mode="after")
    def validate_single_field(self) -> "GoalCheckInUpdate":
        set_fields = [
            name
            for name in ("completed", "count_value")
            if getattr(self, name) is not None
        ]
        if len(set_fields) != 1:
            raise ValueError(
                "exactly one of completed or count_value must be set"
            )
        return self
