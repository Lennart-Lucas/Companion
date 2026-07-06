"""Calendar-aligned quota period boundaries for check-in scheduling."""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta

from app.models.check_in_scheduling import QuotaPeriodUnit


@dataclass(frozen=True)
class QuotaPeriod:
    """Inclusive local-calendar period bounds."""

    start: date
    end: date


def local_date(dt: datetime) -> date:
    """Calendar date in the datetime's own timezone (or UTC)."""
    if dt.tzinfo is None:
        return dt.date()
    return dt.astimezone(dt.tzinfo).date()


def iso_week_start(day: date) -> date:
    """Monday of the ISO week containing [day]."""
    return day - timedelta(days=day.weekday())


def iso_week_number(day: date) -> int:
    return day.isocalendar()[1]


def iso_year(day: date) -> int:
    return day.isocalendar()[0]


def period_for_date(
    day: date,
    *,
    interval: int,
    unit: QuotaPeriodUnit,
) -> QuotaPeriod:
    """Return the calendar period containing [day]."""
    if interval < 1:
        raise ValueError("interval must be >= 1")

    if unit == QuotaPeriodUnit.weeks:
        year = iso_year(day)
        week = iso_week_number(day)
        block_index = (week - 1) // interval
        first_week = block_index * interval + 1
        period_start = iso_week_start(date.fromisocalendar(year, first_week, 1))
        last_week = min(first_week + interval - 1, 52 if year % 4 != 0 else 53)
        # Handle year boundary: last week may belong to next ISO year
        try:
            period_end = date.fromisocalendar(year, last_week, 7)
        except ValueError:
            # Week 53 edge case — walk from start
            period_end = period_start + timedelta(weeks=interval) - timedelta(days=1)
        else:
            # Ensure end covers full N weeks from start
            expected_end = period_start + timedelta(weeks=interval) - timedelta(days=1)
            if period_end < expected_end:
                period_end = expected_end
        return QuotaPeriod(start=period_start, end=period_end)

    if unit == QuotaPeriodUnit.months:
        block_index = (day.month - 1) // interval
        start_month = block_index * interval + 1
        period_start = date(day.year, start_month, 1)
        end_month = start_month + interval - 1
        last_day = calendar.monthrange(day.year, end_month)[1]
        period_end = date(day.year, end_month, last_day)
        return QuotaPeriod(start=period_start, end=period_end)

    if unit == QuotaPeriodUnit.years:
        block_index = (day.year - 1) // interval
        start_year = block_index * interval + 1
        end_year = start_year + interval - 1
        return QuotaPeriod(
            start=date(start_year, 1, 1),
            end=date(end_year, 12, 31),
        )

    raise ValueError(f"unsupported period unit: {unit}")


def _next_period_start(period: QuotaPeriod, *, unit: QuotaPeriodUnit, interval: int) -> date:
    if unit == QuotaPeriodUnit.weeks:
        return period.end + timedelta(days=1)
    if unit == QuotaPeriodUnit.months:
        next_month = period.end.month + 1
        next_year = period.end.year
        if next_month > 12:
            next_month = 1
            next_year += 1
        return date(next_year, next_month, 1)
    if unit == QuotaPeriodUnit.years:
        return date(period.end.year + 1, 1, 1)
    raise ValueError(f"unsupported period unit: {unit}")


def iter_periods_overlapping(
    window_start: date,
    window_end: date,
    *,
    interval: int,
    unit: QuotaPeriodUnit,
) -> list[QuotaPeriod]:
    """All periods whose inclusive range overlaps [window_start, window_end]."""
    if window_start > window_end:
        return []

    periods: list[QuotaPeriod] = []
    current = period_for_date(window_start, interval=interval, unit=unit)
    seen: set[tuple[date, date]] = set()

    while current.start <= window_end:
        key = (current.start, current.end)
        if key not in seen:
            seen.add(key)
            periods.append(current)
        if current.end >= window_end:
            break
        next_start = _next_period_start(current, unit=unit, interval=interval)
        current = period_for_date(next_start, interval=interval, unit=unit)

    return periods


def combine_date_and_time(day: date, reference: datetime) -> datetime:
    """UTC datetime at [day] with time-of-day from [reference]."""
    ref = reference if reference.tzinfo else reference.replace(tzinfo=UTC)
    local = ref.astimezone(ref.tzinfo)
    local_dt = datetime.combine(day, time(local.hour, local.minute, local.second), tzinfo=local.tzinfo)
    return local_dt.astimezone(UTC)


def add_days(day: date, days: int) -> date:
    return day + timedelta(days=days)
