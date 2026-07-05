from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from dateutil.rrule import rruleset, rrulestr

from app.scheduling.types import (
    OverrideScope,
    ScheduleBundle,
    ScheduleOverrideData,
)


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _tz(bundle: ScheduleBundle) -> ZoneInfo:
    return ZoneInfo(bundle.timezone)


def _dtstart_local(bundle: ScheduleBundle) -> datetime:
    return bundle.dtstart.astimezone(_tz(bundle))


def _local_time(bundle: ScheduleBundle) -> time:
    return _dtstart_local(bundle).timetz().replace(tzinfo=None)


def _occurrence_at_local_date(bundle: ScheduleBundle, d: date) -> datetime:
    tz = _tz(bundle)
    local_dt = datetime.combine(d, _local_time(bundle), tzinfo=tz)
    return local_dt.astimezone(UTC)


def _local_date(bundle: ScheduleBundle, dt: datetime) -> date:
    return dt.astimezone(_tz(bundle)).date()


def schedule_local_date(bundle: ScheduleBundle, dt: datetime) -> date:
    """Calendar date of [dt] in the schedule's IANA timezone."""
    return _local_date(bundle, dt)


def end_datetime_before_occurrence(
    bundle: ScheduleBundle, occurrence_at: datetime
) -> datetime:
    """Last scheduled instant before [occurrence_at]'s local calendar day."""
    prev_d = _local_date(bundle, occurrence_at) - timedelta(days=1)
    return _occurrence_at_local_date(bundle, prev_d)


def _is_excluded(bundle: ScheduleBundle, dt: datetime) -> bool:
    return _local_date(bundle, dt) in bundle.exclusions


def _in_window(dt: datetime, start: datetime, end: datetime) -> bool:
    t = _ensure_utc(dt)
    return _ensure_utc(start) <= t <= _ensure_utc(end)


def _build_ruleset(bundle: ScheduleBundle) -> rruleset:
    rs = rruleset()
    # Anchor RRULE in the schedule timezone so BYDAY matches local weekdays.
    dtstart = _dtstart_local(bundle)

    if bundle.rrule:
        rule = rrulestr(f"RRULE:{bundle.rrule}", dtstart=dtstart)
        rs.rrule(rule)

    for d in sorted(bundle.rdates):
        rs.rdate(_occurrence_at_local_date(bundle, d))

    for d in sorted(bundle.exclusions):
        rs.exdate(_occurrence_at_local_date(bundle, d))

    if not bundle.rrule and not bundle.rdates:
        rs.rdate(dtstart)

    return rs


def _expand_schedule_only(
    bundle: ScheduleBundle,
    *,
    start: datetime,
    end: datetime,
    max_count: int,
) -> list[datetime]:
    start = _ensure_utc(start)
    end = _ensure_utc(end)
    rs = _build_ruleset(bundle)
    results = [_ensure_utc(dt) for dt in rs.between(start, end, inc=True)]
    return results[:max_count]


def _expand_with_overrides(
    bundle: ScheduleBundle,
    *,
    start: datetime,
    end: datetime,
    max_count: int,
) -> list[datetime]:
    start = _ensure_utc(start)
    end = _ensure_utc(end)

    from_date_overrides = sorted(
        [o for o in bundle.overrides if o.scope == OverrideScope.from_date],
        key=lambda o: _ensure_utc(o.effective_at),
    )

    if not from_date_overrides and not bundle.overrides:
        raw = _expand_schedule_only(bundle, start=start, end=end, max_count=max_count)
        return _apply_exclusions(bundle, raw, max_count)

    segments: list[tuple[datetime, datetime, ScheduleBundle, bool]] = []
    cursor = start
    active = bundle

    for override in from_date_overrides:
        boundary = _ensure_utc(override.effective_at)
        if boundary > end:
            break
        if cursor < boundary:
            seg_end = min(boundary, end)
            if cursor < seg_end:
                segments.append((cursor, seg_end, active, True))
        active = ScheduleBundle(
            dtstart=override.replacement.dtstart,
            timezone=override.replacement.timezone,
            rrule=override.replacement.rrule,
            rdates=list(override.replacement.rdates),
            exclusions=set(override.replacement.exclusions),
            overrides=[],
            schedule_id=override.replacement.schedule_id,
        )
        cursor = boundary

    if cursor <= end:
        segments.append((cursor, end, active, False))

    if not segments:
        segments = [(start, end, bundle, False)]

    results: list[datetime] = []
    for seg_start, seg_end, seg_bundle, exclusive_end in segments:
        if seg_start > seg_end:
            continue
        chunk = _expand_schedule_only(
            seg_bundle, start=seg_start, end=seg_end, max_count=max_count - len(results)
        )
        boundary = _ensure_utc(seg_end)
        for occ in chunk:
            occ_utc = _ensure_utc(occ)
            if exclusive_end and occ_utc >= boundary:
                continue
            results.append(occ)
        if len(results) >= max_count:
            break

    results = sorted(set(_ensure_utc(r) for r in results))

    single_overrides = [
        o for o in bundle.overrides if o.scope == OverrideScope.single_occurrence
    ]
    for override in single_overrides:
        eff = _ensure_utc(override.effective_at)
        results = [r for r in results if r != eff]
        replacement = override.replacement
        if not replacement.rrule and not replacement.rdates:
            repl_at = _ensure_utc(replacement.dtstart)
            if _in_window(repl_at, start, end):
                results.append(repl_at)
        else:
            repl_occurrences = _expand_schedule_only(
                replacement, start=eff - timedelta(seconds=1), end=eff + timedelta(seconds=1), max_count=1
            )
            if repl_occurrences:
                results.append(repl_occurrences[0])
            elif _in_window(eff, start, end):
                results.append(eff)

    results = sorted(results)
    return _apply_exclusions(bundle, results, max_count)


def _apply_exclusions(
    bundle: ScheduleBundle, occurrences: list[datetime], max_count: int
) -> list[datetime]:
    filtered = [o for o in occurrences if not _is_excluded(bundle, o)]
    return filtered[:max_count]


_BYDAY_TO_ISO = {
    "MO": 1,
    "TU": 2,
    "WE": 3,
    "TH": 4,
    "FR": 5,
    "SA": 6,
    "SU": 7,
}


def _byday_weekdays_from_rrule(rrule: str | None) -> set[int] | None:
    if not rrule:
        return None
    upper = rrule.upper()
    marker = "BYDAY="
    if marker not in upper:
        return None
    segment = upper.split(marker, 1)[1].split(";", 1)[0]
    days = {_BYDAY_TO_ISO[part] for part in segment.split(",") if part in _BYDAY_TO_ISO}
    return days or None


def ensure_dtstart_occurrence(
    bundle: ScheduleBundle,
    occurrences: list[datetime],
    *,
    start: datetime,
    end: datetime,
    max_count: int | None = None,
    anchor_at: datetime | None = None,
) -> list[datetime]:
    """Include the schedule start calendar day when it falls in [start, end].

    Check-in schedules treat the chosen start date as day one even when the
    RRULE pattern would not otherwise generate that day (e.g. BYDAY filters).

    [anchor_at] overrides [bundle.dtstart] for the calendar day to inject
    (e.g. tracker/goal start_date when schedule dtstart drifted by timezone).
    """
    if not bundle.rrule and not bundle.rdates:
        return occurrences

    dtstart_day = schedule_local_date(bundle, anchor_at or bundle.dtstart)
    if dtstart_day in bundle.exclusions:
        return occurrences

    byday = _byday_weekdays_from_rrule(bundle.rrule)
    if byday is not None:
        weekday = dtstart_day.isoweekday()
        if weekday not in byday:
            if byday <= {1, 2, 3, 4, 5} and weekday in (6, 7):
                return occurrences

    anchor_occ = _occurrence_at_local_date(bundle, dtstart_day)
    if not _in_window(anchor_occ, start, end):
        return occurrences

    anchor_utc = _ensure_utc(anchor_occ)
    for occ in occurrences:
        if schedule_local_date(bundle, occ) == dtstart_day:
            return occurrences

    merged = sorted(set(occurrences + [anchor_utc]))
    if max_count is not None:
        return merged[:max_count]
    return merged


def expand_occurrences(
    bundle: ScheduleBundle,
    *,
    start: datetime,
    end: datetime,
    max_count: int = 500,
) -> list[datetime]:
    if max_count < 1:
        return []
    start = _ensure_utc(start)
    end = _ensure_utc(end)
    if start > end:
        return []

    if bundle.overrides:
        return _expand_with_overrides(
            bundle, start=start, end=end, max_count=max_count
        )

    raw = _expand_schedule_only(bundle, start=start, end=end, max_count=max_count)
    return _apply_exclusions(bundle, raw, max_count)
