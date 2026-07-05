from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_active_user, get_db
from app.models.user import User
from app.schemas.event import (
    EventCreate,
    EventListResponse,
    EventResponse,
    EventUpdate,
)
from app.services import event_service

router = APIRouter(prefix="/events", tags=["events"])


@router.post("", response_model=EventResponse, status_code=201)
async def create_event(
    body: EventCreate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> EventResponse:
    event = await event_service.create_event(session, user, body)
    return event_service.event_to_response(event)


@router.get("", response_model=EventListResponse)
async def list_events(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> EventListResponse:
    items, total = await event_service.list_events(
        session, user, limit=limit, offset=offset
    )
    return EventListResponse(
        items=[event_service.event_to_response(e) for e in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> EventResponse:
    event = await event_service.get_event(session, user, event_id)
    return event_service.event_to_response(event)


@router.patch("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: int,
    body: EventUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> EventResponse:
    event = await event_service.update_event(session, user, event_id, body)
    return event_service.event_to_response(event)


@router.delete("/{event_id}", status_code=204)
async def delete_event(
    event_id: int,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_active_user),
) -> None:
    await event_service.delete_event(session, user, event_id)
