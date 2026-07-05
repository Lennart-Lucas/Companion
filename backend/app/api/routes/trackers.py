from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.tracker import (
    TrackerCreate,
    TrackerListResponse,
    TrackerResponse,
    TrackerUpdate,
)
from app.schemas.tracker_check_in import (
    TrackerCheckInCreate,
    TrackerCheckInListResponse,
    TrackerCheckInResponse,
    TrackerCheckInUpdate,
)
from app.services import tracker_check_in_service, tracker_service

router = APIRouter(prefix="/trackers", tags=["trackers"])


@router.post("", response_model=TrackerResponse, status_code=201)
async def create_tracker(
    body: TrackerCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerResponse:
    tracker = await tracker_service.create_tracker(session, user, body)
    return TrackerResponse.model_validate(tracker)


@router.get("", response_model=TrackerListResponse)
async def list_trackers(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerListResponse:
    items, total = await tracker_service.list_trackers(
        session, user, limit=limit, offset=offset
    )
    return TrackerListResponse(
        items=[TrackerResponse.model_validate(t) for t in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{tracker_id}", response_model=TrackerResponse)
async def get_tracker(
    tracker_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerResponse:
    tracker = await tracker_service.get_tracker(session, user, tracker_id)
    return TrackerResponse.model_validate(tracker)


@router.patch("/{tracker_id}", response_model=TrackerResponse)
async def update_tracker(
    tracker_id: int,
    body: TrackerUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerResponse:
    tracker = await tracker_service.update_tracker(session, user, tracker_id, body)
    return TrackerResponse.model_validate(tracker)


@router.delete("/{tracker_id}", status_code=204)
async def delete_tracker(
    tracker_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await tracker_service.delete_tracker(session, user, tracker_id)


@router.get("/{tracker_id}/check-ins", response_model=TrackerCheckInListResponse)
async def list_tracker_check_ins(
    tracker_id: int,
    from_: datetime = Query(alias="from"),
    to: datetime = Query(),
    max_count: int = Query(default=500, ge=1, le=5000),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerCheckInListResponse:
    items = await tracker_check_in_service.list_check_ins(
        session, user, tracker_id, start=from_, end=to, max_count=max_count
    )
    return TrackerCheckInListResponse(items=items)


@router.post(
    "/{tracker_id}/check-ins",
    response_model=TrackerCheckInResponse,
    status_code=201,
)
async def create_tracker_check_in(
    tracker_id: int,
    body: TrackerCheckInCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerCheckInResponse:
    return await tracker_check_in_service.create_check_in(
        session, user, tracker_id, body
    )


@router.patch(
    "/{tracker_id}/check-ins/{check_in_id}",
    response_model=TrackerCheckInResponse,
)
async def update_tracker_check_in(
    tracker_id: int,
    check_in_id: int,
    body: TrackerCheckInUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> TrackerCheckInResponse:
    return await tracker_check_in_service.update_check_in(
        session, user, tracker_id, check_in_id, body
    )
