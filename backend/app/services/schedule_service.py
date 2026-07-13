from datetime import UTC, date, datetime

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.schedule import Schedule
from app.models.schedule_exclusion import ScheduleExclusion
from app.models.schedule_override import ScheduleOverride
from app.models.schedule_specific_date import ScheduleSpecificDate
from app.models.user import User
from app.scheduling.expander import (
    end_datetime_before_occurrence,
    expand_occurrences,
    schedule_local_date,
)
from app.scheduling.rrule_codec import is_recurring
from app.scheduling.types import (
    OverrideScope as EngineOverrideScope,
    ScheduleBundle,
    ScheduleOverrideData,
)
from app.scheduling.validators import (
    ScheduleValidationError,
    validate_schedule_payload,
)
from app.schemas.schedule import (
    ExclusionsReplace,
    OccurrenceExclusionCreate,
    RdatesReplace,
    ScheduleCreate,
    ScheduleOverrideCreate,
    ScheduleResponse,
    ScheduleUpdate,
    SpecificDatesReplace,
)
from app.services.productivity_helpers import apply_list_filters, soft_delete


def _engine_override_scope(value: str) -> EngineOverrideScope:
    return EngineOverrideScope(value)


def _schedule_to_bundle(
    schedule: Schedule,
    *,
    replacement_cache: dict[int, ScheduleBundle] | None = None,
) -> ScheduleBundle:
    cache = replacement_cache if replacement_cache is not None else {}

    overrides: list[ScheduleOverrideData] = []
    for ov in schedule.overrides:
        repl_id = ov.replacement_schedule_id
        if repl_id not in cache:
            repl = ov.replacement_schedule
            cache[repl_id] = _schedule_to_bundle(
                repl, replacement_cache=cache
            )
        overrides.append(
            ScheduleOverrideData(
                scope=_engine_override_scope(ov.scope),
                effective_at=ov.effective_at,
                replacement=cache[repl_id],
            )
        )

    return ScheduleBundle(
        dtstart=schedule.dtstart,
        timezone=schedule.timezone,
        rrule=schedule.rrule,
        rdates=[d.occurrence_date for d in schedule.specific_dates],
        exclusions={e.excluded_date for e in schedule.exclusions},
        overrides=overrides,
        schedule_id=schedule.id,
    )


def schedule_to_response(schedule: Schedule) -> ScheduleResponse:
    rdates = [d.occurrence_date for d in schedule.specific_dates]
    return ScheduleResponse(
        id=schedule.id,
        dtstart=schedule.dtstart,
        rrule=schedule.rrule,
        start_date=schedule.start_date,
        end_date=schedule.end_date,
        timezone=schedule.timezone,
        rdates=schedule.specific_dates,
        exdates=schedule.exclusions,
        overrides=schedule.overrides,
        is_recurring=is_recurring(
            schedule.rrule,
            rdates,
            quota_times=schedule.quota_times,
            quota_period_weeks=schedule.quota_period_weeks,
        ),
        quota_times=schedule.quota_times,
        quota_period_weeks=schedule.quota_period_weeks,
        created_at=schedule.created_at,
        updated_at=schedule.updated_at,
    )


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _clip_query_window(
    schedule: Schedule,
    *,
    start: datetime,
    end: datetime,
) -> tuple[datetime, datetime]:
    window_start = _ensure_utc(start)
    window_end = _ensure_utc(end)
    if schedule.start_date is not None:
        window_start = max(window_start, _ensure_utc(schedule.start_date))
    if schedule.end_date is not None:
        window_end = min(window_end, _ensure_utc(schedule.end_date))
    if window_start > window_end:
        return window_start, window_start
    return window_start, window_end


def _validate_create_or_update(
    *,
    rrule: str | None,
    rdates: list[date] | None,
    exdates: list[date] | None,
    timezone: str,
    quota_times: int | None = None,
    quota_period_weeks: int | None = None,
) -> None:
    try:
        validate_schedule_payload(
            rrule=rrule,
            rdates=rdates,
            exdates=exdates,
            timezone=timezone,
            quota_times=quota_times,
            quota_period_weeks=quota_period_weeks,
        )
    except ScheduleValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


async def _load_schedule(
    session: AsyncSession, schedule_id: int, user_id: int
) -> Schedule:
    stmt = (
        select(Schedule)
        .where(
            Schedule.id == schedule_id,
            Schedule.user_id == user_id,
            Schedule.deleted_at.is_(None),
        )
        .options(
            selectinload(Schedule.specific_dates),
            selectinload(Schedule.exclusions),
            selectinload(Schedule.overrides).selectinload(
                ScheduleOverride.replacement_schedule
            ).selectinload(Schedule.specific_dates),
            selectinload(Schedule.overrides).selectinload(
                ScheduleOverride.replacement_schedule
            ).selectinload(Schedule.exclusions),
        )
    )
    result = await session.execute(stmt)
    schedule = result.scalar_one_or_none()
    if schedule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Schedule not found",
        )
    return schedule


async def get_schedule(
    session: AsyncSession, user: User, schedule_id: int
) -> Schedule:
    return await _load_schedule(session, schedule_id, user.id)


async def _get_schedule_owned(
    session: AsyncSession, schedule_id: int, user_id: int
) -> Schedule:
    return await _load_schedule(session, schedule_id, user_id)


async def create_schedule(
    session: AsyncSession,
    user: User,
    data: ScheduleCreate,
) -> Schedule:
    _validate_create_or_update(
        rrule=data.rrule,
        rdates=data.rdates,
        exdates=data.exdates,
        timezone=data.timezone,
        quota_times=data.quota_times,
        quota_period_weeks=data.quota_period_weeks,
    )

    schedule = Schedule(
        user_id=user.id,
        dtstart=data.dtstart,
        rrule=data.rrule,
        start_date=data.start_date,
        end_date=data.end_date,
        timezone=data.timezone,
        quota_times=data.quota_times,
        quota_period_weeks=data.quota_period_weeks,
    )
    session.add(schedule)
    await session.flush()

    if data.rdates:
        for d in sorted(set(data.rdates)):
            session.add(
                ScheduleSpecificDate(schedule_id=schedule.id, occurrence_date=d)
            )

    if data.exdates:
        for d in sorted(set(data.exdates)):
            session.add(
                ScheduleExclusion(schedule_id=schedule.id, excluded_date=d)
            )

    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def list_schedules(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Schedule], int]:
    limit = min(max(limit, 1), 100)
    offset = max(offset, 0)

    count_stmt = select(func.count()).select_from(Schedule).where(
        Schedule.user_id == user.id
    )
    count_stmt = apply_list_filters(count_stmt, Schedule, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()

    stmt = select(Schedule).where(Schedule.user_id == user.id)
    stmt = apply_list_filters(stmt, Schedule, updated_since=updated_since)
    stmt = (
        stmt.options(
            selectinload(Schedule.specific_dates),
            selectinload(Schedule.exclusions),
            selectinload(Schedule.overrides),
        )
        .order_by(Schedule.id)
        .limit(limit)
        .offset(offset)
    )
    result = await session.execute(stmt)
    return list(result.scalars().all()), total


async def update_schedule(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    data: ScheduleUpdate,
) -> Schedule:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)

    dtstart = data.dtstart if data.dtstart is not None else schedule.dtstart
    timezone = data.timezone if data.timezone is not None else schedule.timezone
    rrule = data.rrule if "rrule" in data.model_fields_set else schedule.rrule
    quota_times = (
        data.quota_times
        if "quota_times" in data.model_fields_set
        else schedule.quota_times
    )
    quota_period_weeks = (
        data.quota_period_weeks
        if "quota_period_weeks" in data.model_fields_set
        else schedule.quota_period_weeks
    )
    start_date = (
        data.start_date if "start_date" in data.model_fields_set else schedule.start_date
    )
    end_date = (
        data.end_date if "end_date" in data.model_fields_set else schedule.end_date
    )
    if "truncate_before_occurrence_at" in data.model_fields_set:
        if data.truncate_before_occurrence_at is None:
            end_date = None
        else:
            bundle = _schedule_to_bundle(schedule)
            end_date = end_datetime_before_occurrence(
                bundle, data.truncate_before_occurrence_at
            )

    if (
        start_date is not None
        and end_date is not None
        and end_date <= start_date
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_date must be after start_date",
        )

    rdates = (
        data.rdates
        if "rdates" in data.model_fields_set
        else [d.occurrence_date for d in schedule.specific_dates]
    )
    exdates = (
        data.exdates
        if "exdates" in data.model_fields_set
        else [e.excluded_date for e in schedule.exclusions]
    )

    _validate_create_or_update(
        rrule=rrule,
        rdates=rdates,
        exdates=exdates,
        timezone=timezone,
        quota_times=quota_times,
        quota_period_weeks=quota_period_weeks,
    )

    if data.dtstart is not None:
        schedule.dtstart = data.dtstart
    if data.timezone is not None:
        schedule.timezone = data.timezone
    if "rrule" in data.model_fields_set:
        schedule.rrule = data.rrule
    if "quota_times" in data.model_fields_set:
        schedule.quota_times = data.quota_times
    if "quota_period_weeks" in data.model_fields_set:
        schedule.quota_period_weeks = data.quota_period_weeks
    if "start_date" in data.model_fields_set:
        schedule.start_date = data.start_date
    if "end_date" in data.model_fields_set or "truncate_before_occurrence_at" in data.model_fields_set:
        schedule.end_date = end_date

    if "rdates" in data.model_fields_set and data.rdates is not None:
        for row in list(schedule.specific_dates):
            await session.delete(row)
        await session.flush()
        for d in sorted(set(data.rdates)):
            session.add(
                ScheduleSpecificDate(schedule_id=schedule.id, occurrence_date=d)
            )

    if "exdates" in data.model_fields_set and data.exdates is not None:
        for row in list(schedule.exclusions):
            await session.delete(row)
        await session.flush()
        for d in sorted(set(data.exdates)):
            session.add(
                ScheduleExclusion(schedule_id=schedule.id, excluded_date=d)
            )

    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def exclude_occurrence(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    data: OccurrenceExclusionCreate,
) -> Schedule:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)
    bundle = _schedule_to_bundle(schedule)
    excluded = schedule_local_date(bundle, data.occurrence_at)
    dates = {e.excluded_date for e in schedule.exclusions}
    dates.add(excluded)
    return await replace_exclusions(
        session, user, schedule_id, ExclusionsReplace(dates=sorted(dates))
    )


async def delete_schedule(
    session: AsyncSession,
    user: User,
    schedule_id: int,
) -> None:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)
    await soft_delete(schedule)


async def replace_specific_dates(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    data: SpecificDatesReplace,
) -> Schedule:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)
    if schedule.rrule is not None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Schedule uses RRULE; replace rdates via PATCH instead",
        )

    for row in list(schedule.specific_dates):
        await session.delete(row)
    await session.flush()

    for d in sorted(set(data.dates)):
        session.add(
            ScheduleSpecificDate(schedule_id=schedule.id, occurrence_date=d)
        )
    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def replace_exclusions(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    data: ExclusionsReplace,
) -> Schedule:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)

    for row in list(schedule.exclusions):
        await session.delete(row)
    await session.flush()

    for d in sorted(set(data.dates)):
        session.add(
            ScheduleExclusion(schedule_id=schedule.id, excluded_date=d)
        )
    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def _validate_replacement_schedule(
    session: AsyncSession,
    user: User,
    base_schedule_id: int,
    replacement_schedule_id: int,
) -> Schedule:
    if replacement_schedule_id == base_schedule_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Replacement schedule cannot be the same as the base schedule",
        )

    replacement = await _get_schedule_owned(
        session, replacement_schedule_id, user.id
    )

    if replacement.overrides:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Replacement schedule cannot have overrides in v1",
        )

    return replacement


async def add_override(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    data: ScheduleOverrideCreate,
) -> Schedule:
    schedule = await _load_schedule(session, schedule_id, user.id)
    await _validate_replacement_schedule(
        session,
        user,
        schedule_id,
        data.replacement_schedule_id,
    )

    override = ScheduleOverride(
        schedule_id=schedule.id,
        scope=data.scope.value,
        effective_at=data.effective_at,
        replacement_schedule_id=data.replacement_schedule_id,
    )
    session.add(override)
    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def remove_override(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    override_id: int,
) -> Schedule:
    schedule = await _get_schedule_owned(session, schedule_id, user.id)
    override = next((o for o in schedule.overrides if o.id == override_id), None)
    if override is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Override not found",
        )
    await session.delete(override)
    await session.flush()
    return await _load_schedule(session, schedule.id, user.id)


async def preview_occurrences(
    session: AsyncSession,
    user: User,
    schedule_id: int,
    *,
    start: datetime,
    end: datetime,
    max_count: int,
) -> list[datetime]:
    schedule = await _load_schedule(session, schedule_id, user.id)
    window_start, window_end = _clip_query_window(
        schedule, start=start, end=end
    )
    if window_start > window_end:
        return []
    bundle = _schedule_to_bundle(schedule)
    return expand_occurrences(
        bundle, start=window_start, end=window_end, max_count=max_count
    )
