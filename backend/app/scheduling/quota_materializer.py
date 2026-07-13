"""Materialize quota check-in slots for goals and trackers."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any, Callable, TypeVar

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.schedule import Schedule
from app.scheduling.quota_periods import (
    QuotaPeriod,
    datetime_at_schedule_time,
    iter_quota_periods,
    local_date,
    next_local_day,
    quota_period_end_date,
)
from app.services.check_in_slot_helpers import (
    SLOT_KIND_ACTIVE,
    SLOT_KIND_FAILED,
    SLOT_KIND_LOCKED,
)

T = TypeVar("T")


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def is_check_in_logged(check_in: object) -> bool:
    if getattr(check_in, "skipped", False):
        return True
    return (
        getattr(check_in, "completed", None) is not None
        or getattr(check_in, "count_value", None) is not None
        or getattr(check_in, "value_seconds", None) is not None
        or getattr(check_in, "pulse_score", None) is not None
    )


def compute_quota_display_at(
    check_in: object,
    *,
    period_end_at: datetime,
    timezone: str,
    now: datetime,
) -> datetime:
    slot_kind = getattr(check_in, "slot_kind", None)
    locked_at = getattr(check_in, "locked_at", None)
    spawned_at = getattr(check_in, "spawned_at", None) or getattr(
        check_in, "check_in_at", None
    )

    if slot_kind == SLOT_KIND_FAILED:
        return _ensure_utc(period_end_at)

    if slot_kind == SLOT_KIND_LOCKED and locked_at is not None:
        return _ensure_utc(locked_at)

    if spawned_at is None:
        return _ensure_utc(period_end_at)

    spawned_at = _ensure_utc(spawned_at)
    now = _ensure_utc(now)
    period_end = _ensure_utc(period_end_at)
    today = datetime_at_schedule_time(
        local_date(now, timezone),
        dtstart=spawned_at,
        timezone=timezone,
    )
    spawned_day = datetime_at_schedule_time(
        local_date(spawned_at, timezone),
        dtstart=spawned_at,
        timezone=timezone,
    )
    display = max(spawned_day, today)
    if display > period_end:
        return period_end
    return display


async def _load_period_slots(
    session: AsyncSession,
    check_in_model: type[T],
    parent_fk_column: Any,
    parent_id: int,
    period_start_at: datetime,
) -> dict[int, T]:
    result = await session.execute(
        select(check_in_model).where(
            parent_fk_column == parent_id,
            check_in_model.period_start_at == _ensure_utc(period_start_at),
        )
    )
    slots: dict[int, T] = {}
    for row in result.scalars().all():
        if row.slot_index is not None:
            slots[row.slot_index] = row
    return slots


def _create_quota_slot(
    check_in_model: type[T],
    *,
    parent_fk_name: str,
    parent_id: int,
    period_start_at: datetime,
    slot_index: int,
    spawned_at: datetime,
    slot_kind: str,
    locked_at: datetime | None = None,
) -> T:
    spawned_at = _ensure_utc(spawned_at)
    # Distinct check_in_at per slot when spawned_at repeats (failed slots at period end).
    check_in_at = spawned_at + timedelta(microseconds=slot_index)
    kwargs: dict[str, object] = {
        parent_fk_name: parent_id,
        "check_in_at": check_in_at,
        "spawned_at": spawned_at,
        "period_start_at": _ensure_utc(period_start_at),
        "slot_index": slot_index,
        "slot_kind": slot_kind,
    }
    if locked_at is not None:
        kwargs["locked_at"] = _ensure_utc(locked_at)
    return check_in_model(**kwargs)


async def _materialize_period(
    session: AsyncSession,
    *,
    check_in_model: type[T],
    parent_fk_column: Any,
    parent_fk_name: str,
    parent_id: int,
    period: QuotaPeriod,
    quota_times: int,
    timezone: str,
    dtstart: datetime,
    now: datetime,
    slots_by_index: dict[int, T],
) -> None:
    now = _ensure_utc(now)
    period_start = _ensure_utc(period.start_at)
    period_end = _ensure_utc(period.end_at)
    period_end_day = local_date(period_end, timezone)

    if now >= period_start and 1 not in slots_by_index:
        slot = _create_quota_slot(
            check_in_model,
            parent_fk_name=parent_fk_name,
            parent_id=parent_id,
            period_start_at=period_start,
            slot_index=1,
            spawned_at=period_start,
            slot_kind=SLOT_KIND_ACTIVE,
        )
        session.add(slot)
        slots_by_index[1] = slot

    for index in range(1, quota_times):
        current = slots_by_index.get(index)
        if current is None:
            continue
        if current.slot_kind != SLOT_KIND_LOCKED:
            continue
        next_index = index + 1
        if next_index in slots_by_index:
            continue
        if current.locked_at is None:
            continue
        next_day = next_local_day(current.locked_at, timezone)
        if next_day > period_end_day:
            continue
        next_spawn = datetime_at_schedule_time(
            next_day, dtstart=dtstart, timezone=timezone
        )
        slot = _create_quota_slot(
            check_in_model,
            parent_fk_name=parent_fk_name,
            parent_id=parent_id,
            period_start_at=period_start,
            slot_index=next_index,
            spawned_at=next_spawn,
            slot_kind=SLOT_KIND_ACTIVE,
        )
        session.add(slot)
        slots_by_index[next_index] = slot

    today = local_date(now, timezone)
    period_ended = today > period_end_day

    if period_ended:
        for index in range(1, quota_times + 1):
            slot = slots_by_index.get(index)
            if slot is None:
                failed = _create_quota_slot(
                    check_in_model,
                    parent_fk_name=parent_fk_name,
                    parent_id=parent_id,
                    period_start_at=period_start,
                    slot_index=index,
                    spawned_at=period_end,
                    slot_kind=SLOT_KIND_FAILED,
                    locked_at=period_end,
                )
                session.add(failed)
                slots_by_index[index] = failed
                continue
            if slot.slot_kind == SLOT_KIND_ACTIVE and not is_check_in_logged(slot):
                slot.slot_kind = SLOT_KIND_FAILED
                slot.locked_at = period_end


async def materialize_quota_check_ins(
    session: AsyncSession,
    *,
    check_in_model: type[T],
    parent_fk_column: Any,
    parent_fk_name: str,
    parent_id: int,
    entity_start: datetime,
    entity_end: datetime | None,
    schedule: Schedule,
    window_start: datetime,
    window_end: datetime,
    now: datetime | None = None,
    max_count: int = 500,
) -> list[T]:
    assert schedule.quota_times is not None
    assert schedule.quota_period_weeks is not None

    now = _ensure_utc(now or datetime.now(UTC))
    timezone = schedule.timezone
    periods = iter_quota_periods(
        entity_start,
        period_weeks=schedule.quota_period_weeks,
        window_start=window_start,
        window_end=window_end,
        entity_end=entity_end,
        dtstart=schedule.dtstart,
        timezone=timezone,
        max_count=max_count,
    )

    all_slots: list[T] = []
    for period in periods:
        slots_by_index = await _load_period_slots(
            session,
            check_in_model,
            parent_fk_column,
            parent_id,
            period.start_at,
        )
        await _materialize_period(
            session,
            check_in_model=check_in_model,
            parent_fk_column=parent_fk_column,
            parent_fk_name=parent_fk_name,
            parent_id=parent_id,
            period=period,
            quota_times=schedule.quota_times,
            timezone=timezone,
            dtstart=schedule.dtstart,
            now=now,
            slots_by_index=slots_by_index,
        )
        all_slots.extend(slots_by_index.values())

    await session.flush()

    visible: list[T] = []
    for slot in all_slots:
        if slot.period_start_at is None:
            continue
        period_end_day = quota_period_end_date(
            local_date(slot.period_start_at, timezone),
            period_weeks=schedule.quota_period_weeks,
        )
        period_end_at = datetime_at_schedule_time(
            period_end_day,
            dtstart=schedule.dtstart,
            timezone=timezone,
        )
        display_at = compute_quota_display_at(
            slot,
            period_end_at=period_end_at,
            timezone=timezone,
            now=now,
        )
        if _ensure_utc(window_start) <= display_at <= _ensure_utc(window_end):
            visible.append(slot)

    visible.sort(
        key=lambda s: compute_quota_display_at(
            s,
            period_end_at=datetime_at_schedule_time(
                quota_period_end_date(
                    local_date(s.period_start_at, timezone),
                    period_weeks=schedule.quota_period_weeks,
                ),
                dtstart=schedule.dtstart,
                timezone=timezone,
            ),
            timezone=timezone,
            now=now,
        )
    )
    return visible[:max_count]


def quota_check_in_failed(check_in: object) -> bool:
    return getattr(check_in, "slot_kind", None) == SLOT_KIND_FAILED


def build_display_at_resolver(
    schedule: Schedule,
    *,
    now: datetime | None = None,
) -> Callable[[object], datetime]:
    now = _ensure_utc(now or datetime.now(UTC))
    timezone = schedule.timezone
    assert schedule.quota_period_weeks is not None

    def resolve(check_in: object) -> datetime:
        period_start = getattr(check_in, "period_start_at", None)
        if period_start is None:
            return _ensure_utc(getattr(check_in, "check_in_at"))
        period_end_day = quota_period_end_date(
            local_date(period_start, timezone),
            period_weeks=schedule.quota_period_weeks,
        )
        period_end_at = datetime_at_schedule_time(
            period_end_day,
            dtstart=schedule.dtstart,
            timezone=timezone,
        )
        return compute_quota_display_at(
            check_in,
            period_end_at=period_end_at,
            timezone=timezone,
            now=now,
        )

    return resolve
