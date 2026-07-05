from datetime import datetime

from pydantic import BaseModel, Field

from app.models.task import TaskPriority, TaskStatus


class OccurrenceSubtaskStateResponse(BaseModel):
    id: int
    title: str
    completed: bool

    model_config = {"from_attributes": True}


class TaskOccurrenceResponse(BaseModel):
    id: int
    occurrence_at: datetime
    status: TaskStatus
    priority: TaskPriority
    updated_at: datetime
    subtasks: list[OccurrenceSubtaskStateResponse] = []

    model_config = {"from_attributes": True}


class TaskOccurrenceListResponse(BaseModel):
    items: list[TaskOccurrenceResponse]


class TaskOccurrenceUpdate(BaseModel):
    status: TaskStatus | None = None
    priority: TaskPriority | None = None


class TaskOccurrenceEnsure(BaseModel):
    occurrence_at: datetime


class OccurrenceSubtaskToggle(BaseModel):
    completed: bool


class SubtaskTemplateCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    sort_order: int = Field(default=0, ge=0)


class SubtaskTemplateResponse(BaseModel):
    id: int
    title: str
    sort_order: int

    model_config = {"from_attributes": True}


class SubtasksReplace(BaseModel):
    subtasks: list[SubtaskTemplateCreate] = Field(default_factory=list)
