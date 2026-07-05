from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.schedule import (
    ExclusionsReplace,
    OccurrenceExclusionCreate,
    ScheduleCreate,
    ScheduleListResponse,
    ScheduleOverrideCreate,
    SchedulePreviewRequest,
    SchedulePreviewResponse,
    ScheduleResponse,
    ScheduleUpdate,
    SpecificDatesReplace,
)
from app.services import schedule_service

router = APIRouter(prefix="/schedules", tags=["schedules"])


def _to_response(schedule) -> ScheduleResponse:
    return schedule_service.schedule_to_response(schedule)


@router.post("", response_model=ScheduleResponse, status_code=201)
async def create_schedule(
    body: ScheduleCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.create_schedule(session, user, body)
    return _to_response(schedule)


@router.get("", response_model=ScheduleListResponse)
async def list_schedules(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleListResponse:
    items, total = await schedule_service.list_schedules(
        session, user, limit=limit, offset=offset
    )
    return ScheduleListResponse(
        items=[_to_response(s) for s in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{schedule_id}", response_model=ScheduleResponse)
async def get_schedule(
    schedule_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.get_schedule(session, user, schedule_id)
    return _to_response(schedule)


@router.patch("/{schedule_id}", response_model=ScheduleResponse)
async def update_schedule(
    schedule_id: int,
    body: ScheduleUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.update_schedule(
        session, user, schedule_id, body
    )
    return _to_response(schedule)


@router.delete("/{schedule_id}", status_code=204)
async def delete_schedule(
    schedule_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await schedule_service.delete_schedule(session, user, schedule_id)


@router.post("/{schedule_id}/preview", response_model=SchedulePreviewResponse)
async def preview_schedule(
    schedule_id: int,
    body: SchedulePreviewRequest,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> SchedulePreviewResponse:
    occurrences = await schedule_service.preview_occurrences(
        session,
        user,
        schedule_id,
        start=body.from_,
        end=body.to,
        max_count=body.max_count,
    )
    return SchedulePreviewResponse(occurrences=occurrences)


@router.put("/{schedule_id}/specific-dates", response_model=ScheduleResponse)
async def replace_specific_dates(
    schedule_id: int,
    body: SpecificDatesReplace,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.replace_specific_dates(
        session, user, schedule_id, body
    )
    return _to_response(schedule)


@router.put("/{schedule_id}/exclusions", response_model=ScheduleResponse)
async def replace_exclusions(
    schedule_id: int,
    body: ExclusionsReplace,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.replace_exclusions(
        session, user, schedule_id, body
    )
    return _to_response(schedule)


@router.post("/{schedule_id}/exclusions/occurrence", response_model=ScheduleResponse)
async def exclude_occurrence(
    schedule_id: int,
    body: OccurrenceExclusionCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.exclude_occurrence(
        session, user, schedule_id, body
    )
    return _to_response(schedule)


@router.post("/{schedule_id}/overrides", response_model=ScheduleResponse)
async def add_override(
    schedule_id: int,
    body: ScheduleOverrideCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.add_override(
        session, user, schedule_id, body
    )
    return _to_response(schedule)


@router.delete("/{schedule_id}/overrides/{override_id}", response_model=ScheduleResponse)
async def remove_override(
    schedule_id: int,
    override_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> ScheduleResponse:
    schedule = await schedule_service.remove_override(
        session, user, schedule_id, override_id
    )
    return _to_response(schedule)
