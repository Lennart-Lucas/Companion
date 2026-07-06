"""Lazy materialization for times-per-period check-in scheduling."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, date, datetime
from typing import TypeVar

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.check_in_scheduling import CheckInMode, QuotaPeriodUnit, SlotKind
from app.models.goal import Goal
from app.models.goal_check_in import GoalCheckIn
from app.models.tracker import Tracker
from app.models.tracker_check_in import TrackerCheckIn
from app.scheduling.quota_periods import (
    QuotaPeriod,
    add_days,
    combine_date_and_time,
    iter_periods_overlapping,
    local_date,
    period_for_date,
)

CheckInT = TypeVar("CheckInT", TrackerCheckIn, GoalCheckIn)


def entity_uses_quota_mode(entity: Tracker | Goal) -> bool:
    return entity.check_in_mode == CheckInMode.times_per_period.value


def _quota_config(entity: Tracker | Goal) -> tuple[int, int, QuotaPeriodUnit]:
    if entity.quota_times is None or entity.quota_period_interval is None:
        raise ValueError("quota fields required for times_per_period mode")
    if entity.quota_period_unit is None:
        raise ValueError("quota_period_unit required for times_per_period mode")
    return (
        entity.quota_times,
        entity.quota_period_interval,
        QuotaPeriodUnit(entity.quota_period_unit),
    )


def _entity_start_day(entity: Tracker | Goal) -> datetime:
    return entity.start_date


def _entity_end_day(entity: Tracker | Goal) -> datetime | None:
    return entity.end_date


def _check_in_in_period(
    check_in: CheckInT,
    period: QuotaPeriod,
) -> bool:
    spawned_day = local_date(check_in.spawned_at)
    return period.start <= spawned_day <= period.end


def _locked_slots_in_period(
    check_ins: list[CheckInT],
    period: QuotaPeriod,
) -> list[CheckInT]:
    return [
        c
        for c in check_ins
        if c.slot_kind == SlotKind.locked.value and _check_in_in_period(c, period)
    ]


def _active_slot_in_period(
    check_ins: list[CheckInT],
    period: QuotaPeriod,
) -> CheckInT | None:
    for c in check_ins:
        if c.slot_kind == SlotKind.active.value and _check_in_in_period(c, period):
            return c
    return None


def _period_miss_in_period(
    check_ins: list[CheckInT],
    period: QuotaPeriod,
) -> CheckInT | None:
    for c in check_ins:
        if c.slot_kind == SlotKind.period_miss.value and _check_in_in_period(c, period):
            return c
    return None


def _last_locked_day(
    locked: list[CheckInT],
) -> date | None:
    if not locked:
        return None
    days = [local_date(c.locked_at or c.check_in_at) for c in locked]
    return max(days)


def _spawn_day_for_period(
    entity: Tracker | Goal,
    period: QuotaPeriod,
    locked: list[CheckInT],
) -> date:
    entity_start = local_date(_entity_start_day(entity))
    period_start = max(period.start, entity_start)
    last_locked = _last_locked_day(locked)
    if last_locked is None:
        return period_start
    return max(period_start, add_days(last_locked, 1))


def _period_in_entity_window(
    entity: Tracker | Goal,
    period: QuotaPeriod,
) -> bool:
    entity_start = local_date(_entity_start_day(entity))
    if period.end < entity_start:
        return False
    end = _entity_end_day(entity)
    if end is not None and period.start > local_date(end):
        return False
    return True


async def _load_check_ins_for_entity(
    session: AsyncSession,
    entity: Tracker | Goal,
    check_in_model: type[CheckInT],
    entity_id_field: str,
    *,
    window_start: datetime,
    window_end: datetime,
) -> list[CheckInT]:
    entity_id = entity.id
    result = await session.execute(
        select(check_in_model).where(
            getattr(check_in_model, entity_id_field) == entity_id,
            check_in_model.spawned_at >= window_start,
            check_in_model.spawned_at <= window_end,
        )
    )
    return list(result.scalars().all())


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


async def materialize_quota_check_ins(
    session: AsyncSession,
    entity: Tracker | Goal,
    check_in_model: type[CheckInT],
    entity_id_field: str,
    *,
    start: datetime,
    end: datetime,
    now: datetime | None = None,
    is_logged: Callable[[CheckInT], bool] | None = None,
) -> list[CheckInT]:
    """Materialize quota-mode check-ins for periods overlapping the window."""
    if not entity_uses_quota_mode(entity):
        return []

    quota_times, interval, unit = _quota_config(entity)
    current = _ensure_utc(now or datetime.now(UTC))
    today = local_date(current)

    window_start = _ensure_utc(start)
    window_end = _ensure_utc(end)

    window_start_day = local_date(window_start)
    window_end_day = local_date(window_end)

    periods = iter_periods_overlapping(
        window_start_day,
        window_end_day,
        interval=interval,
        unit=unit,
    )

    # Load all check-ins that might belong to these periods (wider query)
    if periods:
        query_start = combine_date_and_time(periods[0].start, entity.start_date)
        query_end = combine_date_and_time(periods[-1].end, entity.start_date)
    else:
        query_start = window_start
        query_end = window_end

    stored = await _load_check_ins_for_entity(
        session,
        entity,
        check_in_model,
        entity_id_field,
        window_start=query_start,
        window_end=query_end,
    )

    result: list[CheckInT] = []

    for period in periods:
        if not _period_in_entity_window(entity, period):
            continue

        period_check_ins = [c for c in stored if _check_in_in_period(c, period)]
        locked = _locked_slots_in_period(period_check_ins, period)
        locked_count = len(locked)
        period_ended = period.end < today

        if period_ended:
            # Remove unlogged active slots
            for active in list(period_check_ins):
                if active.slot_kind == SlotKind.active.value:
                    if is_logged and is_logged(active):
                        continue
                    await session.delete(active)
                    stored.remove(active)
                    period_check_ins.remove(active)

            if locked_count < quota_times:
                miss = _period_miss_in_period(period_check_ins, period)
                if miss is None:
                    miss_at = combine_date_and_time(period.end, entity.start_date)
                    miss = check_in_model(
                        **{entity_id_field: entity.id},
                        check_in_at=miss_at,
                        spawned_at=miss_at,
                        locked_at=None,
                        slot_kind=SlotKind.period_miss.value,
                    )
                    session.add(miss)
                    await session.flush()
                    stored.append(miss)
                    period_check_ins.append(miss)
                    result.append(miss)
                else:
                    result.append(miss)
            continue

        # Period active or future
        if locked_count >= quota_times:
            for active in list(period_check_ins):
                if active.slot_kind == SlotKind.active.value:
                    await session.delete(active)
                    stored.remove(active)
            continue

        active = _active_slot_in_period(period_check_ins, period)
        if active is not None:
            result.append(active)
            continue

        spawn_day = _spawn_day_for_period(entity, period, locked)
        if spawn_day > period.end:
            continue
        if period.start > today:
            continue

        spawn_at = combine_date_and_time(spawn_day, entity.start_date)
        active = check_in_model(
            **{entity_id_field: entity.id},
            check_in_at=spawn_at,
            spawned_at=spawn_at,
            locked_at=None,
            slot_kind=SlotKind.active.value,
        )
        session.add(active)
        await session.flush()
        stored.append(active)
        result.append(active)

    await session.flush()
    return sorted(result, key=lambda c: c.check_in_at)


def lock_check_in_on_log(
    check_in: CheckInT,
    entity: Tracker | Goal,
    *,
    now: datetime | None = None,
) -> None:
    """Lock an active quota slot to the log day."""
    current = _ensure_utc(now or datetime.now(UTC))
    lock_day = local_date(current)
    locked_at = combine_date_and_time(lock_day, entity.start_date)
    check_in.locked_at = locked_at
    check_in.check_in_at = locked_at
    check_in.slot_kind = SlotKind.locked.value


def compute_display_at(
    check_in: CheckInT,
    *,
    entity: Tracker | Goal | None = None,
    now: datetime | None = None,
) -> datetime:
    """Compute client display timestamp (floating active slots drift to today in quota mode)."""
    if entity is not None and not entity_uses_quota_mode(entity):
        return check_in.check_in_at

    current = _ensure_utc(now or datetime.now(UTC))
    today = local_date(current)

    if check_in.slot_kind == SlotKind.active.value:
        spawned_day = local_date(check_in.spawned_at)
        display_day = spawned_day if spawned_day >= today else today
        return combine_date_and_time(display_day, check_in.spawned_at)

    if check_in.locked_at is not None:
        return check_in.locked_at
    return check_in.check_in_at
