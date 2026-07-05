from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.task import TaskCreate, TaskListResponse, TaskResponse, TaskUpdate
from app.schemas.task_occurrence import (
    OccurrenceSubtaskToggle,
    SubtasksReplace,
    SubtaskTemplateResponse,
    TaskOccurrenceEnsure,
    TaskOccurrenceListResponse,
    TaskOccurrenceResponse,
    TaskOccurrenceUpdate,
)
from app.services import task_occurrence_service, task_service

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.post("", response_model=TaskResponse, status_code=201)
async def create_task(
    body: TaskCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskResponse:
    task = await task_service.create_task(session, user, body)
    return task_service.task_to_response(task)


@router.get("", response_model=TaskListResponse)
async def list_tasks(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskListResponse:
    items, total = await task_service.list_tasks(
        session, user, limit=limit, offset=offset
    )
    return TaskListResponse(
        items=[task_service.task_to_response(t) for t in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskResponse:
    task = await task_service.get_task(session, user, task_id)
    return task_service.task_to_response(task)


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    body: TaskUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskResponse:
    task = await task_service.update_task(session, user, task_id, body)
    return task_service.task_to_response(task)


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await task_service.delete_task(session, user, task_id)


@router.get("/{task_id}/occurrences", response_model=TaskOccurrenceListResponse)
async def list_task_occurrences(
    task_id: int,
    from_: datetime = Query(alias="from"),
    to: datetime = Query(),
    max_count: int = Query(default=500, ge=1, le=5000),
    existing_only: bool = Query(default=False),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskOccurrenceListResponse:
    items = await task_occurrence_service.list_occurrences(
        session,
        user,
        task_id,
        start=from_,
        end=to,
        max_count=max_count,
        existing_only=existing_only,
    )
    return TaskOccurrenceListResponse(items=items)


@router.post(
    "/{task_id}/occurrences",
    response_model=TaskOccurrenceResponse,
    status_code=201,
)
async def ensure_task_occurrence(
    task_id: int,
    body: TaskOccurrenceEnsure,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskOccurrenceResponse:
    return await task_occurrence_service.ensure_occurrence(
        session, user, task_id, occurrence_at=body.occurrence_at
    )


@router.patch(
    "/{task_id}/occurrences/{occurrence_id}",
    response_model=TaskOccurrenceResponse,
)
async def update_task_occurrence(
    task_id: int,
    occurrence_id: int,
    body: TaskOccurrenceUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskOccurrenceResponse:
    return await task_occurrence_service.update_occurrence(
        session, user, task_id, occurrence_id, body
    )


@router.put("/{task_id}/subtasks", response_model=list[SubtaskTemplateResponse])
async def replace_task_subtasks(
    task_id: int,
    body: SubtasksReplace,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> list[SubtaskTemplateResponse]:
    templates = await task_occurrence_service.replace_subtask_templates(
        session, user, task_id, body
    )
    return [SubtaskTemplateResponse.model_validate(t) for t in templates]


@router.patch(
    "/{task_id}/occurrences/{occurrence_id}/subtasks/{subtask_id}",
    response_model=TaskOccurrenceResponse,
)
async def toggle_occurrence_subtask(
    task_id: int,
    occurrence_id: int,
    subtask_id: int,
    body: OccurrenceSubtaskToggle,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TaskOccurrenceResponse:
    return await task_occurrence_service.toggle_occurrence_subtask(
        session,
        user,
        task_id,
        occurrence_id,
        subtask_id,
        completed=body.completed,
    )
