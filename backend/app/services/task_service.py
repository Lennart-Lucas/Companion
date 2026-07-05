from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.task import Task, TaskPriority, TaskStatus
from app.models.user import User
from app.schemas.task import TaskCreate, TaskResponse, TaskUpdate
from app.schemas.task_occurrence import SubtaskTemplateResponse
from app.services.productivity_helpers import (
    apply_list_filters,
    assert_goal_owned,
    assert_project_owned,
    clamp_pagination,
    soft_delete,
)
from app.services.schedule_attachment import (
    apply_entity_schedule_update,
    resolve_entity_schedule_id,
)
from app.services.task_occurrence_service import (
    add_subtask_templates,
    create_sole_occurrence,
    task_is_recurring,
)


async def get_task(session: AsyncSession, user: User, task_id: int) -> Task:
    return await _load_task(session, task_id, user.id)


async def _load_task(session: AsyncSession, task_id: int, user_id: int) -> Task:
    stmt = (
        select(Task)
        .where(
            Task.id == task_id,
            Task.user_id == user_id,
            Task.deleted_at.is_(None),
        )
        .options(
            selectinload(Task.subtask_templates),
            selectinload(Task.schedule),
        )
    )
    result = await session.execute(stmt)
    task = result.scalar_one_or_none()
    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Task not found",
        )
    return task


def task_to_response(task: Task) -> TaskResponse:
    return TaskResponse(
        id=task.id,
        name=task.name,
        planned_at=task.planned_at,
        deadline=task.deadline,
        description=task.description,
        project_id=task.project_id,
        goal_id=task.goal_id,
        schedule_id=task.schedule_id,
        status=TaskStatus(task.status),
        priority=TaskPriority(task.priority),
        is_recurring=task_is_recurring(task),
        subtasks=[
            SubtaskTemplateResponse.model_validate(t) for t in task.subtask_templates
        ],
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


async def _validate_task_parents(
    session: AsyncSession,
    user_id: int,
    *,
    project_id: int | None,
    goal_id: int | None,
) -> None:
    if project_id is not None and goal_id is not None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="task cannot have both project_id and goal_id",
        )
    await assert_project_owned(session, project_id, user_id)
    await assert_goal_owned(session, goal_id, user_id)


async def _sync_sole_occurrence(session: AsyncSession, task: Task) -> None:
    if task_is_recurring(task):
        return
    result = await session.execute(
        select(Task)
        .where(Task.id == task.id)
        .options(selectinload(Task.occurrences))
    )
    task = result.scalar_one()
    if len(task.occurrences) == 1:
        occ = task.occurrences[0]
        occ.status = task.status
        occ.priority = task.priority
        if task.deadline is not None:
            occ.occurrence_at = task.deadline
    elif len(task.occurrences) == 0:
        await create_sole_occurrence(session, task)


async def create_task(
    session: AsyncSession, user: User, data: TaskCreate
) -> Task:
    await _validate_task_parents(
        session, user.id, project_id=data.project_id, goal_id=data.goal_id
    )
    resolved_schedule_id = await resolve_entity_schedule_id(
        session,
        user,
        schedule_id=data.schedule_id,
        schedule=data.schedule,
    )

    task = Task(
        user_id=user.id,
        name=data.name,
        planned_at=data.planned_at,
        deadline=data.deadline,
        description=data.description,
        project_id=data.project_id,
        goal_id=data.goal_id,
        schedule_id=resolved_schedule_id,
        status=data.status.value,
        priority=data.priority.value,
    )
    session.add(task)
    await session.flush()

    if resolved_schedule_id:
        await session.refresh(task, attribute_names=["schedule"])

    if data.subtasks:
        await add_subtask_templates(session, task, data.subtasks)
        await session.refresh(task, attribute_names=["subtask_templates"])

    if not task_is_recurring(task):
        await create_sole_occurrence(session, task)

    await session.flush()
    return await _load_task(session, task.id, user.id)


async def list_tasks(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Task], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(Task).where(Task.user_id == user.id)
    base = apply_list_filters(base, Task, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(Task).where(Task.user_id == user.id)
    count_stmt = apply_list_filters(count_stmt, Task, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.options(
            selectinload(Task.subtask_templates),
            selectinload(Task.schedule),
        )
        .order_by(Task.id)
        .limit(limit)
        .offset(offset)
    )
    return list(result.scalars().all()), total


async def update_task(
    session: AsyncSession, user: User, task_id: int, data: TaskUpdate
) -> Task:
    task = await _load_task(session, task_id, user.id)

    if "project_id" in data.model_fields_set or "goal_id" in data.model_fields_set:
        project_id = data.project_id if "project_id" in data.model_fields_set else task.project_id
        goal_id = data.goal_id if "goal_id" in data.model_fields_set else task.goal_id
        await _validate_task_parents(
            session, user.id, project_id=project_id, goal_id=goal_id
        )
        task.project_id = project_id
        task.goal_id = goal_id

    await apply_entity_schedule_update(session, user, task, data)
    if task.schedule_id:
        await session.refresh(task, attribute_names=["schedule"])
    else:
        task.schedule = None

    updates = data.model_dump(
        exclude_unset=True,
        exclude={"project_id", "goal_id", "schedule", "schedule_id"},
    )
    for key, value in updates.items():
        if hasattr(value, "value"):
            setattr(task, key, value.value)
        else:
            setattr(task, key, value)

    await session.flush()
    await _sync_sole_occurrence(session, task)
    await session.flush()
    return await _load_task(session, task.id, user.id)


async def delete_task(session: AsyncSession, user: User, task_id: int) -> None:
    task = await get_task(session, user, task_id)
    await soft_delete(task)
