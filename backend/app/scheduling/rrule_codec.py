"""RFC 5545 RRULE codec and friendly-builder pattern mapping."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime

from dateutil.rrule import rrulestr

# Friendly-builder pattern ids (UI / codec only; not stored in DB).
PATTERN_NONE = "none"
PATTERN_WEEKDAYS = "weekdays"
PATTERN_EVERY_N_DAYS = "every_n_days"
PATTERN_EVERY_N_WEEKS = "every_n_weeks"
PATTERN_EVERY_N_MONTHS = "every_n_months"
PATTERN_EVERY_N_YEARS = "every_n_years"
PATTERN_SPECIFIC_DATES = "specific_dates"
PATTERN_MONTH_DAYS = "month_days"

_ISO_TO_ICAL = {
    1: "MO",
    2: "TU",
    3: "WE",
    4: "TH",
    5: "FR",
    6: "SA",
    7: "SU",
}


@dataclass(frozen=True)
class FriendlyPattern:
    pattern: str
    interval: int | None = None
    weekdays: list[int] | None = None
    month_days: list[int] | None = None


def is_recurring(rrule: str | None, rdates: list[date] | None) -> bool:
    if rrule:
        return True
    return bool(rdates)


def validate_rrule(rrule: str) -> None:
    """Raise ValueError when [rrule] is not parseable."""
    rrulestr(f"RRULE:{rrule}", dtstart=datetime(2000, 1, 1, tzinfo=UTC))


def pattern_to_rrule(
    pattern: str,
    *,
    interval: int | None = None,
    weekdays: list[int] | None = None,
    month_days: list[int] | None = None,
    until: datetime | None = None,
) -> str | None:
    if pattern in (PATTERN_NONE, PATTERN_SPECIFIC_DATES):
        return None

    n = interval or 1
    parts: list[str] = []

    if pattern == PATTERN_EVERY_N_DAYS:
        parts = ["FREQ=DAILY", f"INTERVAL={n}"]
    elif pattern == PATTERN_EVERY_N_WEEKS:
        parts = ["FREQ=WEEKLY", f"INTERVAL={n}"]
    elif pattern == PATTERN_WEEKDAYS:
        if not weekdays:
            raise ValueError("weekdays required for weekdays pattern")
        byday = ",".join(_ISO_TO_ICAL[d] for d in sorted(weekdays))
        parts = ["FREQ=WEEKLY", f"INTERVAL={n}", f"BYDAY={byday}"]
    elif pattern == PATTERN_EVERY_N_MONTHS:
        parts = ["FREQ=MONTHLY", f"INTERVAL={n}"]
    elif pattern == PATTERN_EVERY_N_YEARS:
        parts = ["FREQ=YEARLY", f"INTERVAL={n}"]
    elif pattern == PATTERN_MONTH_DAYS:
        if not month_days:
            raise ValueError("month_days required for month_days pattern")
        bymonthday = ",".join(str(d) for d in sorted(month_days))
        parts = ["FREQ=MONTHLY", f"INTERVAL={n}", f"BYMONTHDAY={bymonthday}"]
    else:
        raise ValueError(f"Unknown pattern: {pattern}")

    if until is not None:
        until_utc = until.astimezone(UTC)
        parts.append(f"UNTIL={until_utc.strftime('%Y%m%dT%H%M%SZ')}")

    return ";".join(parts)


def _weekday_to_iso(wd: object) -> int:
    if hasattr(wd, "weekday"):
        return int(wd.weekday) + 1  # type: ignore[attr-defined]
    if isinstance(wd, int):
        return wd + 1
    raise ValueError(f"Unsupported BYDAY value: {wd!r}")


def rrule_to_pattern(rrule: str) -> FriendlyPattern:
    rule = rrulestr(f"RRULE:{rrule}", dtstart=datetime(2000, 1, 1, tzinfo=UTC))
    interval = rule._interval or 1
    freq = rule._freq
    has_byday = "BYDAY=" in rrule.upper()
    has_bymonthday = "BYMONTHDAY=" in rrule.upper()

    if freq == 3:  # DAILY
        return FriendlyPattern(PATTERN_EVERY_N_DAYS, interval=interval)
    if freq == 2:  # WEEKLY
        if rule._byweekday and has_byday:
            iso_days = sorted({_weekday_to_iso(wd) for wd in rule._byweekday})
            return FriendlyPattern(
                PATTERN_WEEKDAYS, interval=interval, weekdays=iso_days
            )
        return FriendlyPattern(PATTERN_EVERY_N_WEEKS, interval=interval)
    if freq == 1:  # MONTHLY
        if rule._bymonthday and has_bymonthday:
            days = sorted(int(d) for d in rule._bymonthday)
            return FriendlyPattern(
                PATTERN_MONTH_DAYS, interval=interval, month_days=days
            )
        return FriendlyPattern(PATTERN_EVERY_N_MONTHS, interval=interval)
    if freq == 0:  # YEARLY
        return FriendlyPattern(PATTERN_EVERY_N_YEARS, interval=interval)

    raise ValueError(f"Unsupported RRULE: {rrule}")
