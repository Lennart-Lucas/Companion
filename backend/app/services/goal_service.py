from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.goal import Goal
from app.models.user import User
from app.schemas.goal import GoalCreate, GoalUpdate
from app.services import goal_milestone_service
from app.services.productivity_helpers import (
    apply_list_filters,
    assert_schedule_recurring,
    clamp_pagination,
    soft_delete,
)
from app.services.schedule_attachment import (
    apply_entity_schedule_update,
    resolve_entity_schedule_id,
)


async def _load_goal(
    session: AsyncSession, goal_id: int, user_id: int
) -> Goal:
    result = await session.execute(
        select(Goal)
        .where(
            Goal.id == goal_id,
            Goal.user_id == user_id,
            Goal.deleted_at.is_(None),
        )
        .options(
            selectinload(Goal.schedule),
            selectinload(Goal.milestones),
        )
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    return goal


async def get_goal(session: AsyncSession, user: User, goal_id: int) -> Goal:
    return await _load_goal(session, goal_id, user.id)


def _validate_date_range(start_date, end_date) -> None:
    if end_date is not None and end_date <= start_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_date must be after start_date",
        )


async def create_goal(
    session: AsyncSession, user: User, data: GoalCreate
) -> Goal:
    resolved_schedule_id = await resolve_entity_schedule_id(
        session,
        user,
        schedule_id=data.schedule_id,
        schedule=data.schedule,
    )
    if resolved_schedule_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="goal requires schedule_id or schedule",
        )
    await assert_schedule_recurring(session, user, resolved_schedule_id)

    goal = Goal(
        user_id=user.id,
        name=data.name,
        description=data.description,
        icon=data.icon,
        color=data.color,
        schedule_id=resolved_schedule_id,
        start_date=data.start_date,
        end_date=data.end_date,
        goal_type=data.goal_type.value,
        target=data.target,
        unit=data.unit,
        direction=data.direction.value,
    )
    session.add(goal)
    await session.flush()

    if data.milestones:
        await goal_milestone_service.add_milestones(session, goal, data.milestones)

    await session.refresh(goal, attribute_names=["schedule", "milestones"])
    return goal


async def list_goals(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Goal], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(Goal).where(Goal.user_id == user.id)
    base = apply_list_filters(base, Goal, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(Goal).where(Goal.user_id == user.id)
    count_stmt = apply_list_filters(count_stmt, Goal, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.options(selectinload(Goal.milestones))
        .order_by(Goal.id)
        .limit(limit)
        .offset(offset)
    )
    return list(result.scalars().all()), total


async def update_goal(
    session: AsyncSession, user: User, goal_id: int, data: GoalUpdate
) -> Goal:
    goal = await _load_goal(session, goal_id, user.id)
    await apply_entity_schedule_update(session, user, goal, data)
    if goal.schedule_id:
        await assert_schedule_recurring(session, user, goal.schedule_id)
        await session.refresh(goal, attribute_names=["schedule"])
    else:
        goal.schedule = None

    updates = data.model_dump(
        exclude_unset=True,
        exclude={"schedule", "schedule_id"},
    )
    for key, value in updates.items():
        if hasattr(value, "value"):
            setattr(goal, key, value.value)
        else:
            setattr(goal, key, value)

    _validate_date_range(goal.start_date, goal.end_date)

    await session.flush()
    await session.refresh(goal, attribute_names=["schedule", "milestones"])
    return goal


async def delete_goal(session: AsyncSession, user: User, goal_id: int) -> None:
    goal = await get_goal(session, user, goal_id)
    await soft_delete(goal)
