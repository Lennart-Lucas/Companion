"""Shared schedule attach/update helpers for productivity entities."""

from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate
from app.services import schedule_service


class HasScheduleId(Protocol):
    schedule_id: int | None


class ScheduleUpdatePayload(Protocol):
    model_fields_set: set[str]

    @property
    def schedule(self) -> ScheduleCreate | None: ...

    @property
    def schedule_id(self) -> int | None: ...


async def resolve_entity_schedule_id(
    session: AsyncSession,
    user: User,
    *,
    schedule_id: int | None,
    schedule: ScheduleCreate | None,
) -> int | None:
    if schedule is not None:
        created = await schedule_service.create_schedule(session, user, schedule)
        return created.id
    if schedule_id is not None:
        await schedule_service.get_schedule(session, user, schedule_id)
        return schedule_id
    return None


async def apply_entity_schedule_update(
    session: AsyncSession,
    user: User,
    entity: HasScheduleId,
    data: ScheduleUpdatePayload,
) -> None:
    if "schedule" not in data.model_fields_set and "schedule_id" not in data.model_fields_set:
        return
    if data.schedule is not None:
        if entity.schedule_id:
            schedule_payload = ScheduleUpdate(
                dtstart=data.schedule.dtstart,
                timezone=data.schedule.timezone,
                rrule=data.schedule.rrule,
                rdates=data.schedule.rdates,
                exdates=data.schedule.exdates,
                start_date=data.schedule.start_date,
                end_date=data.schedule.end_date,
                quota_times=data.schedule.quota_times,
                quota_period_weeks=data.schedule.quota_period_weeks,
            )
            await schedule_service.update_schedule(
                session, user, entity.schedule_id, schedule_payload
            )
        else:
            entity.schedule_id = await resolve_entity_schedule_id(
                session, user, schedule_id=None, schedule=data.schedule
            )
    elif data.schedule_id is not None:
        await schedule_service.get_schedule(session, user, data.schedule_id)
        entity.schedule_id = data.schedule_id
    elif "schedule_id" in data.model_fields_set:
        entity.schedule_id = None
