from datetime import date
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.scheduling.rrule_codec import is_recurring, validate_rrule


class ScheduleValidationError(ValueError):
    pass


def validate_timezone(tz_name: str) -> None:
    try:
        ZoneInfo(tz_name)
    except ZoneInfoNotFoundError as exc:
        raise ScheduleValidationError(f"Invalid timezone: {tz_name}") from exc


def validate_schedule_payload(
    *,
    rrule: str | None,
    rdates: list[date] | None,
    exdates: list[date] | None,
    timezone: str,
) -> None:
    validate_timezone(timezone)
    if rrule:
        try:
            validate_rrule(rrule)
        except ValueError as exc:
            raise ScheduleValidationError(f"Invalid RRULE: {exc}") from exc
    if not is_recurring(rrule, rdates) and rdates:
        pass  # rdates-only schedules are valid when recurring
    if exdates:
        for d in exdates:
            if not isinstance(d, date):
                raise ScheduleValidationError("exdates must be calendar dates")
