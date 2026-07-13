from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.goal import Goal, GoalType
from app.models.goal_check_in import GoalCheckIn
from app.models.schedule import Schedule
from app.models.user import User
from app.scheduling.expander import ensure_dtstart_occurrence, expand_occurrences
from app.scheduling.quota_materializer import (
    build_display_at_resolver,
    materialize_quota_check_ins,
    quota_check_in_failed,
)
from app.scheduling.rrule_codec import is_quota_schedule
from app.schemas.goal_check_in import (
    GoalCheckInResponse,
    GoalCheckInUpdate,
)
from app.services.check_in_slot_helpers import (
    lock_check_in_slot,
    materialization_fields,
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
    check_in: GoalCheckIn,
    goal_type: GoalType,
    *,
    schedule: Schedule | None = None,
    now: datetime | None = None,
) -> GoalCheckInResponse:
    display_at = _ensure_utc(check_in.check_in_at)
    if schedule is not None and is_quota_schedule(
        schedule.quota_times, schedule.quota_period_weeks
    ):
        display_at = build_display_at_resolver(schedule, now=now)(check_in)

    return GoalCheckInResponse(
        id=check_in.id,
        check_in_at=check_in.check_in_at,
        display_at=display_at,
        goal_type=goal_type,
        completed=check_in.completed,
        count_value=check_in.count_value,
        pulse_score=check_in.pulse_score,
        logged=_check_in_logged(check_in),
        period_start_at=check_in.period_start_at,
        slot_index=check_in.slot_index,
        slot_kind=check_in.slot_kind,
        failed=quota_check_in_failed(check_in),
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
        **materialization_fields(check_in_at),
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
    if is_quota_schedule(schedule.quota_times, schedule.quota_period_weeks):
        return await materialize_quota_check_ins(
            session,
            check_in_model=GoalCheckIn,
            parent_fk_column=GoalCheckIn.goal_id,
            parent_fk_name="goal_id",
            parent_id=goal.id,
            entity_start=goal.start_date,
            entity_end=goal.end_date,
            schedule=schedule,
            window_start=window_start,
            window_end=window_end,
            max_count=max_count,
        )

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


async def _refresh_quota_slots_after_update(
    session: AsyncSession,
    goal: Goal,
    schedule: Schedule,
) -> None:
    window_end = datetime.now(UTC) + timedelta(days=365)
    await materialize_quota_check_ins(
        session,
        check_in_model=GoalCheckIn,
        parent_fk_column=GoalCheckIn.goal_id,
        parent_fk_name="goal_id",
        parent_id=goal.id,
        entity_start=goal.start_date,
        entity_end=goal.end_date,
        schedule=schedule,
        window_start=goal.start_date,
        window_end=window_end,
    )


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
    schedule = await _load_schedule(session, goal.schedule_id, goal.user_id)
    check_ins = await materialize_check_ins(
        session, goal, start=start, end=end, max_count=max_count
    )
    if not check_ins:
        return []

    goal_type = GoalType(goal.goal_type)
    now = datetime.now(UTC)
    return [
        _check_in_to_response(c, goal_type, schedule=schedule, now=now)
        for c in check_ins
    ]


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
    schedule = await _load_schedule(session, goal.schedule_id, goal.user_id)

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

    lock_check_in_slot(check_in)
    await session.flush()

    if is_quota_schedule(schedule.quota_times, schedule.quota_period_weeks):
        await _refresh_quota_slots_after_update(session, goal, schedule)

    now = datetime.now(UTC)
    return _check_in_to_response(
        check_in, goal_type, schedule=schedule, now=now
    )
