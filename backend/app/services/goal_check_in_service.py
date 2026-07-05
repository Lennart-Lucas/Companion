from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.goal import Goal, GoalType
from app.models.goal_check_in import GoalCheckIn
from app.models.user import User
from app.scheduling.expander import ensure_dtstart_occurrence, expand_occurrences
from app.schemas.goal_check_in import (
    GoalCheckInResponse,
    GoalCheckInUpdate,
)
from app.services.schedule_service import _load_schedule, _schedule_to_bundle


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _check_in_logged(check_in: GoalCheckIn) -> bool:
    return (
        check_in.completed is not None
        or check_in.count_value is not None
        or check_in.pulse_score is not None
    )


def _check_in_to_response(
    check_in: GoalCheckIn, goal_type: GoalType
) -> GoalCheckInResponse:
    return GoalCheckInResponse(
        id=check_in.id,
        check_in_at=check_in.check_in_at,
        goal_type=goal_type,
        completed=check_in.completed,
        count_value=check_in.count_value,
        pulse_score=check_in.pulse_score,
        logged=_check_in_logged(check_in),
    )


async def _load_goal_full(
    session: AsyncSession, goal_id: int, user_id: int
) -> Goal:
    result = await session.execute(
        select(Goal)
        .where(Goal.id == goal_id, Goal.user_id == user_id)
        .options(
            selectinload(Goal.schedule),
            selectinload(Goal.check_ins),
        )
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found",
        )
    return goal


async def _get_or_create_check_in(
    session: AsyncSession,
    goal: Goal,
    check_in_at: datetime,
) -> GoalCheckIn:
    check_in_at = _ensure_utc(check_in_at)
    result = await session.execute(
        select(GoalCheckIn).where(
            GoalCheckIn.goal_id == goal.id,
            GoalCheckIn.check_in_at == check_in_at,
        )
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing

    check_in = GoalCheckIn(
        goal_id=goal.id,
        check_in_at=check_in_at,
    )
    session.add(check_in)
    await session.flush()
    goal.check_ins.append(check_in)
    return check_in


def _clip_window(
    goal: Goal,
    *,
    start: datetime,
    end: datetime,
) -> tuple[datetime, datetime]:
    window_start = max(_ensure_utc(start), _ensure_utc(goal.start_date))
    window_end = _ensure_utc(end)
    if goal.end_date is not None:
        window_end = min(window_end, _ensure_utc(goal.end_date))
    if window_start > window_end:
        return window_start, window_start
    return window_start, window_end


async def materialize_check_ins(
    session: AsyncSession,
    goal: Goal,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[GoalCheckIn]:
    window_start, window_end = _clip_window(goal, start=start, end=end)
    if window_start > window_end:
        return []

    schedule = await _load_schedule(session, goal.schedule_id, goal.user_id)
    bundle = _schedule_to_bundle(schedule)
    datetimes = expand_occurrences(
        bundle,
        start=window_start,
        end=window_end,
        max_count=max_count,
    )
    datetimes = ensure_dtstart_occurrence(
        bundle,
        datetimes,
        start=window_start,
        end=window_end,
        max_count=max_count,
        anchor_at=goal.start_date,
    )
    check_ins: list[GoalCheckIn] = []
    for dt in datetimes:
        check_in = await _get_or_create_check_in(session, goal, dt)
        check_ins.append(check_in)
    await session.flush()
    return sorted(check_ins, key=lambda c: c.check_in_at)


async def list_check_ins(
    session: AsyncSession,
    user: User,
    goal_id: int,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[GoalCheckInResponse]:
    goal = await _load_goal_full(session, goal_id, user.id)
    check_ins = await materialize_check_ins(
        session, goal, start=start, end=end, max_count=max_count
    )
    if not check_ins:
        return []

    goal_type = GoalType(goal.goal_type)
    return [_check_in_to_response(c, goal_type) for c in check_ins]


async def get_check_in_owned(
    session: AsyncSession, user: User, goal_id: int, check_in_id: int
) -> GoalCheckIn:
    result = await session.execute(
        select(GoalCheckIn)
        .join(Goal)
        .where(
            GoalCheckIn.id == check_in_id,
            GoalCheckIn.goal_id == goal_id,
            Goal.user_id == user.id,
        )
    )
    check_in = result.scalar_one_or_none()
    if check_in is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Check-in not found",
        )
    return check_in


async def update_check_in(
    session: AsyncSession,
    user: User,
    goal_id: int,
    check_in_id: int,
    data: GoalCheckInUpdate,
) -> GoalCheckInResponse:
    goal = await _load_goal_full(session, goal_id, user.id)
    check_in = await get_check_in_owned(session, user, goal_id, check_in_id)
    goal_type = GoalType(goal.goal_type)

    if goal_type == GoalType.pulse:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="pulse check-ins are system-generated",
        )

    if goal_type == GoalType.task:
        if data.completed is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="task check-in requires completed",
            )
        check_in.completed = data.completed
        check_in.count_value = None
        check_in.pulse_score = None
    elif goal_type == GoalType.count:
        if data.count_value is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="count check-in requires count_value",
            )
        check_in.count_value = data.count_value
        check_in.completed = None
        check_in.pulse_score = None

    await session.flush()
    return _check_in_to_response(check_in, goal_type)
