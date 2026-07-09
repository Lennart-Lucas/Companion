from datetime import UTC, datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tracker import CheckInType, Tracker
from app.models.tracker_check_in import TrackerCheckIn
from app.models.user import User
from app.scheduling.expander import ensure_dtstart_occurrence, expand_occurrences
from app.schemas.tracker_check_in import (
    TrackerCheckInCreate,
    TrackerCheckInResponse,
    TrackerCheckInUpdate,
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


def _check_in_logged(check_in: TrackerCheckIn) -> bool:
    return (
        check_in.skipped
        or check_in.completed is not None
        or check_in.count_value is not None
        or check_in.value_seconds is not None
    )


def _check_in_to_response(
    check_in: TrackerCheckIn, check_in_type: CheckInType
) -> TrackerCheckInResponse:
    return TrackerCheckInResponse(
        id=check_in.id,
        check_in_at=check_in.check_in_at,
        check_in_type=check_in_type,
        completed=check_in.completed,
        count_value=check_in.count_value,
        value_seconds=check_in.value_seconds,
        timer_started_at=check_in.timer_started_at,
        skipped=bool(check_in.skipped),
        logged=_check_in_logged(check_in),
    )


async def _load_tracker_full(
    session: AsyncSession, tracker_id: int, user_id: int
) -> Tracker:
    result = await session.execute(
        select(Tracker).where(Tracker.id == tracker_id, Tracker.user_id == user_id)
    )
    tracker = result.scalar_one_or_none()
    if tracker is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tracker not found",
        )
    return tracker


def _clip_window(
    tracker: Tracker,
    *,
    start: datetime,
    end: datetime,
) -> tuple[datetime, datetime]:
    window_start = max(_ensure_utc(start), _ensure_utc(tracker.start_date))
    window_end = _ensure_utc(end)
    if tracker.end_date is not None:
        window_end = min(window_end, _ensure_utc(tracker.end_date))
    if window_start > window_end:
        return window_start, window_start
    return window_start, window_end


def _check_in_at_in_tracker_window(tracker: Tracker, check_in_at: datetime) -> bool:
    at = _ensure_utc(check_in_at)
    start = _ensure_utc(tracker.start_date)
    if at < start:
        return False
    if tracker.end_date is not None and at > _ensure_utc(tracker.end_date):
        return False
    return True


def _apply_check_in_log(
    check_in: TrackerCheckIn,
    check_in_type: CheckInType,
    data: TrackerCheckInUpdate,
) -> None:
    if data.skipped is True:
        check_in.skipped = True
        check_in.completed = None
        check_in.count_value = None
        check_in.value_seconds = None
        check_in.timer_started_at = None
    elif data.timer_started_at is not None:
        if check_in_type != CheckInType.duration:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="timer_started_at is only valid for duration check-ins",
            )
        if check_in.skipped:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="cannot start timer on a skipped check-in",
            )
        now = datetime.now(UTC)
        if _ensure_utc(check_in.check_in_at) > now:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="cannot start timer on a future check-in",
            )
        check_in.timer_started_at = _ensure_utc(data.timer_started_at)
    elif check_in_type == CheckInType.task:
        if data.completed is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="task check-in requires completed",
            )
        check_in.completed = data.completed
        check_in.count_value = None
        check_in.value_seconds = None
        check_in.skipped = False
    elif check_in_type == CheckInType.count:
        if data.count_value is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="count check-in requires count_value",
            )
        check_in.count_value = data.count_value
        check_in.completed = None
        check_in.value_seconds = None
        check_in.skipped = False
    elif check_in_type == CheckInType.duration:
        if data.value_seconds is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="duration check-in requires value_seconds",
            )
        check_in.value_seconds = data.value_seconds
        check_in.completed = None
        check_in.count_value = None
        check_in.skipped = False
        check_in.timer_started_at = None

    if _check_in_logged(check_in) or check_in.skipped:
        lock_check_in_slot(check_in)


async def create_check_in(
    session: AsyncSession,
    user: User,
    tracker_id: int,
    data: TrackerCheckInCreate,
) -> TrackerCheckInResponse:
    tracker = await _load_tracker_full(session, tracker_id, user.id)
    check_in_at = _ensure_utc(data.check_in_at)

    if not _check_in_at_in_tracker_window(tracker, check_in_at):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="check_in_at is outside the tracker active window",
        )

    now = datetime.now(UTC)
    if check_in_at > now:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="check_in_at cannot be in the future",
        )

    result = await session.execute(
        select(TrackerCheckIn).where(
            TrackerCheckIn.tracker_id == tracker.id,
            TrackerCheckIn.check_in_at == check_in_at,
        )
    )
    existing = result.scalar_one_or_none()
    check_in_type = CheckInType(tracker.check_in_type)
    if existing is not None:
        _apply_check_in_log(existing, check_in_type, data)
        await session.flush()
        return _check_in_to_response(existing, check_in_type)

    check_in = TrackerCheckIn(
        tracker_id=tracker.id,
        check_in_at=check_in_at,
        **materialization_fields(check_in_at),
    )
    session.add(check_in)
    _apply_check_in_log(check_in, check_in_type, data)
    await session.flush()
    return _check_in_to_response(check_in, check_in_type)


async def materialize_check_ins(
    session: AsyncSession,
    tracker: Tracker,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[TrackerCheckIn]:
    window_start, window_end = _clip_window(tracker, start=start, end=end)
    if window_start > window_end:
        return []

    schedule = await _load_schedule(session, tracker.schedule_id, tracker.user_id)
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
        anchor_at=tracker.start_date,
    )
    if not datetimes:
        return []

    normalized = [_ensure_utc(dt) for dt in datetimes]
    result = await session.execute(
        select(TrackerCheckIn).where(
            TrackerCheckIn.tracker_id == tracker.id,
            TrackerCheckIn.check_in_at.in_(normalized),
        )
    )
    existing_by_at = {_ensure_utc(c.check_in_at): c for c in result.scalars().all()}

    check_ins: list[TrackerCheckIn] = []
    for dt in normalized:
        existing = existing_by_at.get(dt)
        if existing is not None:
            check_ins.append(existing)
            continue
        check_in = TrackerCheckIn(
            tracker_id=tracker.id,
            check_in_at=dt,
            **materialization_fields(dt),
        )
        session.add(check_in)
        check_ins.append(check_in)

    await session.flush()
    await _prune_stale_materialized_check_ins(
        session,
        tracker,
        window_start=window_start,
        window_end=window_end,
        valid_ats=set(normalized),
    )
    return sorted(check_ins, key=lambda c: c.check_in_at)


async def _prune_stale_materialized_check_ins(
    session: AsyncSession,
    tracker: Tracker,
    *,
    window_start: datetime,
    window_end: datetime,
    valid_ats: set[datetime],
) -> None:
    result = await session.execute(
        select(TrackerCheckIn).where(
            TrackerCheckIn.tracker_id == tracker.id,
            TrackerCheckIn.check_in_at >= window_start,
            TrackerCheckIn.check_in_at <= window_end,
        )
    )
    for check_in in result.scalars().all():
        at = _ensure_utc(check_in.check_in_at)
        if at in valid_ats or _check_in_logged(check_in) or check_in.timer_started_at is not None:
            continue
        await session.delete(check_in)
    await session.flush()


async def _load_check_ins_in_window(
    session: AsyncSession,
    tracker: Tracker,
    *,
    start: datetime,
    end: datetime,
    max_count: int,
) -> list[TrackerCheckIn]:
    window_start, window_end = _clip_window(tracker, start=start, end=end)
    if window_start > window_end:
        return []

    result = await session.execute(
        select(TrackerCheckIn)
        .where(
            TrackerCheckIn.tracker_id == tracker.id,
            TrackerCheckIn.check_in_at >= window_start,
            TrackerCheckIn.check_in_at <= window_end,
        )
        .order_by(TrackerCheckIn.check_in_at)
        .limit(max_count)
    )
    return list(result.scalars().all())


def _merge_check_ins_by_at(
    *groups: list[TrackerCheckIn],
) -> list[TrackerCheckIn]:
    by_at: dict[datetime, TrackerCheckIn] = {}
    for group in groups:
        for check_in in group:
            by_at[_ensure_utc(check_in.check_in_at)] = check_in
    return sorted(by_at.values(), key=lambda c: c.check_in_at)


async def list_check_ins(
    session: AsyncSession,
    user: User,
    tracker_id: int,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[TrackerCheckInResponse]:
    tracker = await _load_tracker_full(session, tracker_id, user.id)
    materialized = await materialize_check_ins(
        session, tracker, start=start, end=end, max_count=max_count
    )
    materialized_ats = {_ensure_utc(c.check_in_at) for c in materialized}
    stored = await _load_check_ins_in_window(
        session, tracker, start=start, end=end, max_count=max_count
    )
    supplemental = [
        check_in
        for check_in in stored
        if _ensure_utc(check_in.check_in_at) not in materialized_ats
        and _check_in_logged(check_in)
    ]
    check_ins = _merge_check_ins_by_at(materialized, supplemental)
    if not check_ins:
        return []

    check_in_type = CheckInType(tracker.check_in_type)
    return [_check_in_to_response(c, check_in_type) for c in check_ins]


async def get_check_in_owned(
    session: AsyncSession, user: User, tracker_id: int, check_in_id: int
) -> TrackerCheckIn:
    result = await session.execute(
        select(TrackerCheckIn)
        .join(Tracker)
        .where(
            TrackerCheckIn.id == check_in_id,
            TrackerCheckIn.tracker_id == tracker_id,
            Tracker.user_id == user.id,
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
    tracker_id: int,
    check_in_id: int,
    data: TrackerCheckInUpdate,
) -> TrackerCheckInResponse:
    tracker = await _load_tracker_full(session, tracker_id, user.id)
    check_in = await get_check_in_owned(session, user, tracker_id, check_in_id)
    check_in_type = CheckInType(tracker.check_in_type)

    _apply_check_in_log(check_in, check_in_type, data)

    await session.flush()
    return _check_in_to_response(check_in, check_in_type)
