from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.schedule import Schedule
from app.models.task import Task, TaskPriority, TaskStatus
from app.models.task_occurrence import TaskOccurrence
from app.models.task_occurrence_subtask import TaskOccurrenceSubtask
from app.models.task_subtask import TaskSubtask
from app.models.user import User
from app.scheduling.expander import expand_occurrences
from app.scheduling.rrule_codec import is_recurring
from app.schemas.task_occurrence import (
    OccurrenceSubtaskStateResponse,
    SubtaskTemplateCreate,
    SubtasksReplace,
    TaskOccurrenceResponse,
    TaskOccurrenceUpdate,
)
from app.services.schedule_service import _load_schedule, _schedule_to_bundle


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def task_is_recurring(task: Task) -> bool:
    if task.schedule_id is None:
        return False
    if task.schedule is not None:
        rdates = [d.occurrence_date for d in task.schedule.specific_dates]
        return is_recurring(task.schedule.rrule, rdates)
    return True


async def _load_task_full(session: AsyncSession, task_id: int, user_id: int) -> Task:
    stmt = (
        select(Task)
        .where(Task.id == task_id, Task.user_id == user_id)
        .options(
            selectinload(Task.subtask_templates),
            selectinload(Task.schedule),
            selectinload(Task.occurrences).selectinload(
                TaskOccurrence.subtask_states
            ),
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


async def _backfill_subtask_states(
    session: AsyncSession,
    occurrence: TaskOccurrence,
    templates: list[TaskSubtask],
) -> None:
    if not templates:
        return
    if occurrence.id is None:
        await session.flush()
    result = await session.execute(
        select(TaskOccurrenceSubtask.subtask_id).where(
            TaskOccurrenceSubtask.occurrence_id == occurrence.id
        )
    )
    existing = set(result.scalars().all())
    for template in templates:
        if template.id not in existing:
            session.add(
                TaskOccurrenceSubtask(
                    occurrence_id=occurrence.id,
                    subtask_id=template.id,
                    completed=False,
                )
            )


async def _get_or_create_occurrence(
    session: AsyncSession,
    task: Task,
    occurrence_at: datetime,
) -> TaskOccurrence:
    occurrence_at = _ensure_utc(occurrence_at)
    result = await session.execute(
        select(TaskOccurrence).where(
            TaskOccurrence.task_id == task.id,
            TaskOccurrence.occurrence_at == occurrence_at,
        )
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing

    occurrence = TaskOccurrence(
        task_id=task.id,
        occurrence_at=occurrence_at,
        status=task.status,
        priority=task.priority,
    )
    session.add(occurrence)
    await session.flush()
    # Do not touch task.occurrences here — lazy-loading the collection breaks async
    # sessions (MissingGreenlet). The FK on occurrence is enough for persistence.
    template_result = await session.execute(
        select(TaskSubtask)
        .where(TaskSubtask.task_id == task.id)
        .order_by(TaskSubtask.sort_order)
    )
    await _backfill_subtask_states(
        session, occurrence, list(template_result.scalars().all())
    )
    await session.flush()
    return occurrence


def _clip_window(
    schedule: Schedule,
    *,
    start: datetime,
    end: datetime,
) -> tuple[datetime, datetime]:
    window_start = _ensure_utc(start)
    window_end = _ensure_utc(end)
    if schedule.start_date is not None:
        window_start = max(window_start, _ensure_utc(schedule.start_date))
    if schedule.end_date is not None:
        window_end = min(window_end, _ensure_utc(schedule.end_date))
    if window_start > window_end:
        return window_start, window_start
    return window_start, window_end


async def create_sole_occurrence(
    session: AsyncSession,
    task: Task,
    *,
    occurrence_at: datetime | None = None,
) -> TaskOccurrence:
    at = _ensure_utc(occurrence_at or task.deadline or datetime.now(UTC))
    return await _get_or_create_occurrence(session, task, at)


async def materialize_occurrences(
    session: AsyncSession,
    task: Task,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[TaskOccurrence]:
    if task.schedule_id is None:
        return [await create_sole_occurrence(session, task)]

    schedule = await _load_schedule(session, task.schedule_id, task.user_id)
    window_start, window_end = _clip_window(schedule, start=start, end=end)
    if window_start > window_end:
        return []

    bundle = _schedule_to_bundle(schedule)
    datetimes = expand_occurrences(
        bundle, start=window_start, end=window_end, max_count=max_count
    )
    occurrences: list[TaskOccurrence] = []
    for dt in datetimes:
        occ = await _get_or_create_occurrence(session, task, dt)
        await _backfill_subtask_states(session, occ, task.subtask_templates)
        occurrences.append(occ)
    await session.flush()
    return sorted(occurrences, key=lambda o: o.occurrence_at)


def _occurrence_to_response(occurrence: TaskOccurrence) -> TaskOccurrenceResponse:
    template_by_id = {
        s.subtask_id: s.subtask
        for s in occurrence.subtask_states
        if s.subtask is not None
    }
    subtasks: list[OccurrenceSubtaskStateResponse] = []
    def _sort_key(s: TaskOccurrenceSubtask) -> int:
        t = template_by_id.get(s.subtask_id)
        return t.sort_order if t is not None else 0

    for state in sorted(occurrence.subtask_states, key=_sort_key):
        template = state.subtask
        if template is None:
            continue
        subtasks.append(
            OccurrenceSubtaskStateResponse(
                id=template.id,
                title=template.title,
                completed=state.completed,
            )
        )
    return TaskOccurrenceResponse(
        id=occurrence.id,
        occurrence_at=occurrence.occurrence_at,
        status=TaskStatus(occurrence.status),
        priority=TaskPriority(occurrence.priority),
        updated_at=occurrence.updated_at,
        subtasks=subtasks,
    )


async def list_existing_occurrences(
    session: AsyncSession,
    user: User,
    task_id: int,
    *,
    start: datetime,
    end: datetime,
) -> list[TaskOccurrenceResponse]:
    task = await _load_task_full(session, task_id, user.id)
    start = _ensure_utc(start)
    end = _ensure_utc(end)
    stmt = (
        select(TaskOccurrence)
        .where(
            TaskOccurrence.task_id == task.id,
            TaskOccurrence.occurrence_at >= start,
            TaskOccurrence.occurrence_at <= end,
        )
        .options(
            selectinload(TaskOccurrence.subtask_states).selectinload(
                TaskOccurrenceSubtask.subtask
            )
        )
        .order_by(TaskOccurrence.occurrence_at)
    )
    result = await session.execute(stmt)
    return [_occurrence_to_response(o) for o in result.scalars().all()]


async def ensure_occurrence(
    session: AsyncSession,
    user: User,
    task_id: int,
    *,
    occurrence_at: datetime,
) -> TaskOccurrenceResponse:
    task = await _load_task_full(session, task_id, user.id)
    occurrence = await _get_or_create_occurrence(session, task, occurrence_at)
    await _backfill_subtask_states(session, occurrence, task.subtask_templates)
    await session.flush()
    occurrence = await get_occurrence_owned(
        session, user, task_id, occurrence.id
    )
    return _occurrence_to_response(occurrence)


async def list_occurrences(
    session: AsyncSession,
    user: User,
    task_id: int,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
    existing_only: bool = False,
) -> list[TaskOccurrenceResponse]:
    if existing_only:
        return await list_existing_occurrences(
            session, user, task_id, start=start, end=end
        )
    task = await _load_task_full(session, task_id, user.id)
    occurrences = await materialize_occurrences(
        session, task, start=start, end=end, max_count=max_count
    )
    if not occurrences:
        return []
    stmt = (
        select(TaskOccurrence)
        .where(TaskOccurrence.id.in_([o.id for o in occurrences]))
        .options(
            selectinload(TaskOccurrence.subtask_states).selectinload(
                TaskOccurrenceSubtask.subtask
            )
        )
        .order_by(TaskOccurrence.occurrence_at)
    )
    result = await session.execute(stmt)
    loaded = list(result.scalars().all())
    return [_occurrence_to_response(o) for o in loaded]


async def get_occurrence_owned(
    session: AsyncSession, user: User, task_id: int, occurrence_id: int
) -> TaskOccurrence:
    result = await session.execute(
        select(TaskOccurrence)
        .join(Task)
        .where(
            TaskOccurrence.id == occurrence_id,
            TaskOccurrence.task_id == task_id,
            Task.user_id == user.id,
        )
        .options(
            selectinload(TaskOccurrence.subtask_states).selectinload(
                TaskOccurrenceSubtask.subtask
            )
        )
    )
    occurrence = result.scalar_one_or_none()
    if occurrence is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Occurrence not found",
        )
    return occurrence


async def update_occurrence(
    session: AsyncSession,
    user: User,
    task_id: int,
    occurrence_id: int,
    data: TaskOccurrenceUpdate,
) -> TaskOccurrenceResponse:
    task = await _load_task_full(session, task_id, user.id)
    occurrence = await get_occurrence_owned(session, user, task_id, occurrence_id)
    updates = data.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(occurrence, key, value.value if hasattr(value, "value") else value)

    if not task_is_recurring(task):
        if "status" in updates:
            task.status = occurrence.status
        if "priority" in updates:
            task.priority = occurrence.priority

    await session.flush()
    return _occurrence_to_response(occurrence)


async def toggle_occurrence_subtask(
    session: AsyncSession,
    user: User,
    task_id: int,
    occurrence_id: int,
    subtask_id: int,
    *,
    completed: bool,
) -> TaskOccurrenceResponse:
    task = await _load_task_full(session, task_id, user.id)
    occurrence = await get_occurrence_owned(session, user, task_id, occurrence_id)

    result = await session.execute(
        select(TaskOccurrenceSubtask).where(
            TaskOccurrenceSubtask.occurrence_id == occurrence_id,
            TaskOccurrenceSubtask.subtask_id == subtask_id,
        )
    )
    state = result.scalar_one_or_none()
    if state is None:
        template_ids = {t.id for t in task.subtask_templates}
        if subtask_id not in template_ids:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subtask not found",
            )
        state = TaskOccurrenceSubtask(
            occurrence_id=occurrence_id,
            subtask_id=subtask_id,
            completed=completed,
        )
        session.add(state)
    else:
        state.completed = completed

    await session.flush()
    occurrence = await get_occurrence_owned(session, user, task_id, occurrence_id)
    return _occurrence_to_response(occurrence)


async def replace_subtask_templates(
    session: AsyncSession,
    user: User,
    task_id: int,
    data: SubtasksReplace,
) -> list[TaskSubtask]:
    task = await _load_task_full(session, task_id, user.id)

    for row in list(task.subtask_templates):
        await session.delete(row)
    await session.flush()
    task.subtask_templates.clear()

    for idx, item in enumerate(data.subtasks):
        template = TaskSubtask(
            task_id=task.id,
            title=item.title.strip(),
            sort_order=item.sort_order if item.sort_order else idx,
        )
        session.add(template)
        task.subtask_templates.append(template)
    await session.flush()

    for occurrence in task.occurrences:
        await _backfill_subtask_states(session, occurrence, task.subtask_templates)
    await session.flush()
    return task.subtask_templates


async def add_subtask_templates(
    session: AsyncSession,
    task: Task,
    items: list[SubtaskTemplateCreate],
) -> None:
    for idx, item in enumerate(items):
        template = TaskSubtask(
            task_id=task.id,
            title=item.title.strip(),
            sort_order=item.sort_order if item.sort_order else idx,
        )
        session.add(template)
    await session.flush()
