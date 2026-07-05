from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event
from app.models.user import User
from app.schemas.event import EventCreate, EventResponse, EventUpdate
from app.scheduling.rrule_codec import is_recurring
from app.services.productivity_helpers import (
    apply_list_filters,
    clamp_pagination,
    soft_delete,
)
from app.services.schedule_attachment import (
    apply_entity_schedule_update,
    resolve_entity_schedule_id,
)


def _validate_time_range(start_at, end_at) -> None:
    if end_at is not None and end_at <= start_at:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_at must be after start_at",
        )


def event_is_recurring(event: Event) -> bool:
    if event.schedule_id is None:
        return False
    if event.schedule is not None:
        rdates = [d.occurrence_date for d in event.schedule.specific_dates]
        return is_recurring(event.schedule.rrule, rdates)
    return True


async def _load_event(session: AsyncSession, event_id: int, user_id: int) -> Event:
    result = await session.execute(
        select(Event)
        .where(
            Event.id == event_id,
            Event.user_id == user_id,
            Event.deleted_at.is_(None),
        )
        .options(selectinload(Event.schedule))
    )
    event = result.scalar_one_or_none()
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )
    return event


async def get_event(
    session: AsyncSession, user: User, event_id: int
) -> Event:
    return await _load_event(session, event_id, user.id)


def event_to_response(event: Event) -> EventResponse:
    return EventResponse(
        id=event.id,
        name=event.name,
        description=event.description,
        icon=event.icon,
        color=event.color,
        start_at=event.start_at,
        end_at=event.end_at,
        schedule_id=event.schedule_id,
        is_recurring=event_is_recurring(event),
        created_at=event.created_at,
        updated_at=event.updated_at,
    )


async def create_event(
    session: AsyncSession, user: User, data: EventCreate
) -> Event:
    resolved_schedule_id = await resolve_entity_schedule_id(
        session,
        user,
        schedule_id=data.schedule_id,
        schedule=data.schedule,
    )

    event = Event(
        user_id=user.id,
        name=data.name,
        description=data.description,
        icon=data.icon,
        color=data.color,
        start_at=data.start_at,
        end_at=data.end_at,
        schedule_id=resolved_schedule_id,
    )
    session.add(event)
    await session.flush()

    if resolved_schedule_id:
        await session.refresh(event, attribute_names=["schedule"])

    return await _load_event(session, event.id, user.id)


async def list_events(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Event], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(Event).where(Event.user_id == user.id)
    base = apply_list_filters(base, Event, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(Event).where(
        Event.user_id == user.id
    )
    count_stmt = apply_list_filters(count_stmt, Event, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.options(selectinload(Event.schedule))
        .order_by(Event.start_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(result.scalars().all()), total


async def update_event(
    session: AsyncSession, user: User, event_id: int, data: EventUpdate
) -> Event:
    event = await _load_event(session, event_id, user.id)

    await apply_entity_schedule_update(session, user, event, data)
    if event.schedule_id:
        await session.refresh(event, attribute_names=["schedule"])
    else:
        event.schedule = None

    updates = data.model_dump(
        exclude_unset=True,
        exclude={"schedule", "schedule_id"},
    )
    for key, value in updates.items():
        setattr(event, key, value)

    _validate_time_range(event.start_at, event.end_at)
    await session.flush()
    return await _load_event(session, event.id, user.id)


async def delete_event(
    session: AsyncSession, user: User, event_id: int
) -> None:
    event = await get_event(session, user, event_id)
    await soft_delete(event)
