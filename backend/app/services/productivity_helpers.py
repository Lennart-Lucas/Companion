from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import Goal
from app.models.project import Project
from app.schemas.schedule import ScheduleCreate
from app.scheduling.rrule_codec import is_recurring


async def get_goal_owned(
    session: AsyncSession, goal_id: int, user_id: int
) -> Goal:
    result = await session.execute(
        select(Goal).where(
            Goal.id == goal_id,
            Goal.user_id == user_id,
            Goal.deleted_at.is_(None),
        )
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    return goal


async def get_project_owned(
    session: AsyncSession, project_id: int, user_id: int
) -> Project:
    result = await session.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id,
            Project.deleted_at.is_(None),
        )
    )
    project = result.scalar_one_or_none()
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found",
        )
    return project


async def assert_goal_owned(
    session: AsyncSession, goal_id: int | None, user_id: int
) -> None:
    if goal_id is not None:
        await get_goal_owned(session, goal_id, user_id)


async def assert_project_owned(
    session: AsyncSession, project_id: int | None, user_id: int
) -> None:
    if project_id is not None:
        await get_project_owned(session, project_id, user_id)


def clamp_pagination(limit: int, offset: int) -> tuple[int, int]:
    return min(max(limit, 1), 100), max(offset, 0)


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def apply_list_filters(stmt, model, *, updated_since: datetime | None = None):
    stmt = stmt.where(model.deleted_at.is_(None))
    if updated_since is not None:
        since = _ensure_utc(updated_since)
        stmt = stmt.where(model.updated_at > since)
    return stmt


async def soft_delete(entity) -> None:
    entity.deleted_at = datetime.now(UTC)


async def resolve_schedule_id(
    session: AsyncSession,
    user,
    *,
    schedule_id: int | None,
    schedule: ScheduleCreate | None,
) -> int | None:
    from app.services.schedule_attachment import resolve_entity_schedule_id

    return await resolve_entity_schedule_id(
        session,
        user,
        schedule_id=schedule_id,
        schedule=schedule,
    )


async def assert_schedule_recurring(
    session: AsyncSession, user, schedule_id: int
) -> None:
    from app.services import schedule_service

    schedule = await schedule_service.get_schedule(session, user, schedule_id)
    rdates = [d.occurrence_date for d in schedule.specific_dates]
    if not is_recurring(schedule.rrule, rdates):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="tracker schedule must be recurring",
        )
