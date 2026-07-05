from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.project import ProjectStatus
from app.schemas.productivity_common import (
    ProductivityListResponse,
    validate_color_optional,
    validate_name,
)


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    start_date: datetime | None = None
    deadline: datetime | None = None
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    goal_id: int | None = None
    status: ProjectStatus = ProjectStatus.planning

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return validate_name(v)

    @field_validator("color")
    @classmethod
    def check_color(cls, v: str | None) -> str | None:
        return validate_color_optional(v)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    start_date: datetime | None = None
    deadline: datetime | None = None
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    color: str | None = Field(default=None, max_length=32)
    goal_id: int | None = None
    status: ProjectStatus | None = None

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


class ProjectResponse(BaseModel):
    id: int
    name: str
    start_date: datetime | None
    deadline: datetime | None
    description: str | None
    icon: str | None
    color: str | None
    goal_id: int | None
    status: ProjectStatus
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ProjectListResponse(ProductivityListResponse):
    items: list[ProjectResponse]
