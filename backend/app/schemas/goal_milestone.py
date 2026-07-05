from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class MilestoneCreate(BaseModel):
    value: Decimal = Field(gt=0)
    name: str | None = Field(default=None, max_length=255)
    sort_order: int = Field(default=0, ge=0)


class MilestoneUpdate(BaseModel):
    value: Decimal | None = Field(default=None, gt=0)
    name: str | None = Field(default=None, max_length=255)
    sort_order: int | None = Field(default=None, ge=0)


class MilestoneResponse(BaseModel):
    id: int
    value: Decimal
    name: str | None
    sort_order: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MilestonesReplace(BaseModel):
    milestones: list[MilestoneCreate] = Field(default_factory=list)
