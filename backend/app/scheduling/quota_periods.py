"""Quota period boundary calculations (Mon–Sun calendar blocks)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class QuotaPeriod:
    start_at: datetime
    end_at: datetime


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def local_date(dt: datetime, timezone: str) -> date:
    return dt.astimezone(ZoneInfo(timezone)).date()


def week_start_monday(d: date) -> date:
    return d - timedelta(days=d.weekday())


def first_quota_period_start(entity_start: datetime, timezone: str) -> date:
    """Monday of the week containing the entity start date (local calendar)."""
    return week_start_monday(local_date(entity_start, timezone))


def quota_period_start_date(
    entity_start: datetime,
    *,
    period_weeks: int,
    period_index: int,
    timezone: str,
) -> date:
    anchor = first_quota_period_start(entity_start, timezone)
    return anchor + timedelta(days=period_index * period_weeks * 7)


def quota_period_end_date(period_start: date, *, period_weeks: int) -> date:
    """Sunday of the last week in the period."""
    return period_start + timedelta(days=period_weeks * 7 - 1)


def datetime_at_schedule_time(
    day: date,
    *,
    dtstart: datetime,
    timezone: str,
) -> datetime:
    """Combine a local calendar day with the schedule dtstart local time."""
    tz = ZoneInfo(timezone)
    local_dtstart = dtstart.astimezone(tz)
    local_time = local_dtstart.timetz().replace(tzinfo=None)
    combined = datetime.combine(day, local_time, tzinfo=tz)
    return combined.astimezone(UTC)


def quota_period_bounds(
    entity_start: datetime,
    *,
    period_weeks: int,
    period_index: int,
    dtstart: datetime,
    timezone: str,
) -> QuotaPeriod:
    start_day = quota_period_start_date(
        entity_start,
        period_weeks=period_weeks,
        period_index=period_index,
        timezone=timezone,
    )
    end_day = quota_period_end_date(start_day, period_weeks=period_weeks)
    return QuotaPeriod(
        start_at=datetime_at_schedule_time(
            start_day, dtstart=dtstart, timezone=timezone
        ),
        end_at=datetime_at_schedule_time(
            end_day, dtstart=dtstart, timezone=timezone
        ),
    )


def iter_quota_periods(
    entity_start: datetime,
    *,
    period_weeks: int,
    window_start: datetime,
    window_end: datetime,
    entity_end: datetime | None,
    dtstart: datetime,
    timezone: str,
    max_count: int = 500,
) -> list[QuotaPeriod]:
    """Quota periods whose range overlaps [window_start, window_end]."""
    window_start = _ensure_utc(window_start)
    window_end = _ensure_utc(window_end)
    entity_start = _ensure_utc(entity_start)

    periods: list[QuotaPeriod] = []
    index = 0
    while len(periods) < max_count:
        period = quota_period_bounds(
            entity_start,
            period_weeks=period_weeks,
            period_index=index,
            dtstart=dtstart,
            timezone=timezone,
        )
        if entity_end is not None and period.start_at > _ensure_utc(entity_end):
            break

        period_overlaps = (
            period.start_at <= window_end and period.end_at >= window_start
        )
        if period_overlaps:
            periods.append(period)
        elif period.start_at > window_end:
            break
        index += 1
        if index > 10_000:
            break
    return periods


def next_local_day(dt: datetime, timezone: str) -> date:
    return local_date(dt, timezone) + timedelta(days=1)
