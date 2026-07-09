from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.goal import Goal
from app.models.goal_milestone import GoalMilestone
from app.models.user import User
from app.schemas.goal_milestone import (
    MilestoneCreate,
    MilestoneResponse,
    MilestoneUpdate,
    MilestonesReplace,
)
from app.services.goal_milestone_validation import validate_milestones


def _milestone_create_from_row(milestone: GoalMilestone) -> MilestoneCreate:
    return MilestoneCreate(
        value=milestone.value,
        name=milestone.name,
        sort_order=milestone.sort_order,
    )


def _validate_for_goal(goal: Goal, milestones: list[MilestoneCreate]) -> None:
    try:
        validate_milestones(goal.target, goal.direction, milestones)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


async def _load_goal_with_milestones(
    session: AsyncSession, goal_id: int, user_id: int
) -> Goal:
    result = await session.execute(
        select(Goal)
        .where(Goal.id == goal_id, Goal.user_id == user_id)
        .options(selectinload(Goal.milestones))
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    return goal


async def list_milestones(
    session: AsyncSession, user: User, goal_id: int
) -> list[MilestoneResponse]:
    goal = await _load_goal_with_milestones(session, goal_id, user.id)
    return [MilestoneResponse.model_validate(m) for m in goal.milestones]


async def replace_milestones(
    session: AsyncSession,
    user: User,
    goal_id: int,
    data: MilestonesReplace,
) -> list[GoalMilestone]:
    goal = await _load_goal_with_milestones(session, goal_id, user.id)
    _validate_for_goal(goal, data.milestones)

    for row in list(goal.milestones):
        await session.delete(row)
    await session.flush()
    goal.milestones.clear()

    for idx, item in enumerate(data.milestones):
        milestone = GoalMilestone(
            goal_id=goal.id,
            value=item.value,
            name=item.name.strip() if item.name else None,
            sort_order=item.sort_order if item.sort_order else idx,
        )
        session.add(milestone)
        goal.milestones.append(milestone)
    await session.flush()
    return goal.milestones


async def add_milestones(
    session: AsyncSession,
    goal: Goal,
    items: list[MilestoneCreate],
) -> None:
    if items:
        combined = [
            _milestone_create_from_row(milestone) for milestone in goal.milestones
        ] + list(items)
        _validate_for_goal(goal, combined)
    base_order = len(goal.milestones)
    for idx, item in enumerate(items):
        milestone = GoalMilestone(
            goal_id=goal.id,
            value=item.value,
            name=item.name.strip() if item.name else None,
            sort_order=item.sort_order if item.sort_order else base_order + idx,
        )
        session.add(milestone)
    await session.flush()


async def add_milestone(
    session: AsyncSession,
    user: User,
    goal_id: int,
    data: MilestoneCreate,
) -> GoalMilestone:
    goal = await _load_goal_with_milestones(session, goal_id, user.id)
    combined = [
        _milestone_create_from_row(milestone) for milestone in goal.milestones
    ] + [data]
    _validate_for_goal(goal, combined)
    milestone = GoalMilestone(
        goal_id=goal.id,
        value=data.value,
        name=data.name.strip() if data.name else None,
        sort_order=data.sort_order if data.sort_order else len(goal.milestones),
    )
    session.add(milestone)
    await session.flush()
    return milestone


async def get_milestone_owned(
    session: AsyncSession, user: User, goal_id: int, milestone_id: int
) -> GoalMilestone:
    result = await session.execute(
        select(GoalMilestone)
        .join(Goal)
        .where(
            GoalMilestone.id == milestone_id,
            GoalMilestone.goal_id == goal_id,
            Goal.user_id == user.id,
        )
    )
    milestone = result.scalar_one_or_none()
    if milestone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Milestone not found",
        )
    return milestone


async def update_milestone(
    session: AsyncSession,
    user: User,
    goal_id: int,
    milestone_id: int,
    data: MilestoneUpdate,
) -> GoalMilestone:
    milestone = await get_milestone_owned(session, user, goal_id, milestone_id)
    updates = data.model_dump(exclude_unset=True)
    if "name" in updates and updates["name"] is not None:
        updates["name"] = updates["name"].strip() or None
    for key, value in updates.items():
        setattr(milestone, key, value)
    await session.flush()

    goal = await _load_goal_with_milestones(session, goal_id, user.id)
    _validate_for_goal(
        goal,
        [_milestone_create_from_row(row) for row in goal.milestones],
    )
    return milestone


async def delete_milestone(
    session: AsyncSession, user: User, goal_id: int, milestone_id: int
) -> None:
    milestone = await get_milestone_owned(session, user, goal_id, milestone_id)
    await session.delete(milestone)
