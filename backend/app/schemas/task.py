from datetime import datetime
from typing import Self

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.task import TaskPriority, TaskStatus
from app.schemas.productivity_common import ProductivityListResponse, validate_name
from app.schemas.schedule import ScheduleCreate
from app.schemas.task_occurrence import SubtaskTemplateCreate, SubtaskTemplateResponse


class TaskCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    planned_at: datetime | None = None
    deadline: datetime | None = None
    description: str | None = None
    project_id: int | None = None
    goal_id: int | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    status: TaskStatus = TaskStatus.pending
    priority: TaskPriority = TaskPriority.medium
    subtasks: list[SubtaskTemplateCreate] = Field(default_factory=list)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return validate_name(v)

    @model_validator(mode="after")
    def validate_parents_and_schedule(self) -> Self:
        if self.project_id is not None and self.goal_id is not None:
            raise ValueError("task cannot have both project_id and goal_id")
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("task cannot have both schedule_id and schedule")
        if (
            self.planned_at is not None
            and self.deadline is not None
            and self.planned_at > self.deadline
        ):
            raise ValueError("planned_at must be on or before deadline")
        return self


class TaskUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    planned_at: datetime | None = None
    deadline: datetime | None = None
    description: str | None = None
    project_id: int | None = None
    goal_id: int | None = None
    schedule_id: int | None = None
    schedule: ScheduleCreate | None = None
    status: TaskStatus | None = None
    priority: TaskPriority | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str | None) -> str | None:
        if v is None:
            return v
        return validate_name(v)

    @model_validator(mode="after")
    def validate_parents_and_schedule(self) -> Self:
        if self.project_id is not None and self.goal_id is not None:
            raise ValueError("task cannot have both project_id and goal_id")
        if self.schedule_id is not None and self.schedule is not None:
            raise ValueError("task cannot have both schedule_id and schedule")
        planned = self.planned_at
        deadline = self.deadline
        if (
            planned is not None
            and deadline is not None
            and planned > deadline
        ):
            raise ValueError("planned_at must be on or before deadline")
        return self


class TaskResponse(BaseModel):
    id: int
    name: str
    planned_at: datetime | None
    deadline: datetime | None
    description: str | None
    project_id: int | None
    goal_id: int | None
    schedule_id: int | None
    status: TaskStatus
    priority: TaskPriority
    is_recurring: bool
    subtasks: list[SubtaskTemplateResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TaskListResponse(ProductivityListResponse):
    items: list[TaskResponse]
