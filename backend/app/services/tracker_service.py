from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tracker import CheckInType, Tracker
from app.models.user import User
from app.schemas.tracker import (
    TrackerCreate,
    TrackerUpdate,
    validate_tracker_type_fields,
)
from app.services.productivity_helpers import (
    apply_list_filters,
    assert_goal_owned,
    assert_schedule_recurring,
    clamp_pagination,
    soft_delete,
)
from app.services.schedule_attachment import (
    apply_entity_schedule_update,
    resolve_entity_schedule_id,
)


async def _load_tracker(
    session: AsyncSession, tracker_id: int, user_id: int
) -> Tracker:
    result = await session.execute(
        select(Tracker).where(
            Tracker.id == tracker_id,
            Tracker.user_id == user_id,
            Tracker.deleted_at.is_(None),
        )
    )
    tracker = result.scalar_one_or_none()
    if tracker is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tracker not found",
        )
    return tracker


async def get_tracker(session: AsyncSession, user: User, tracker_id: int) -> Tracker:
    return await _load_tracker(session, tracker_id, user.id)


def _validate_merged_type_fields(
    check_in_type: CheckInType,
    *,
    target: Decimal | None,
    unit: str | None,
) -> None:
    try:
        validate_tracker_type_fields(check_in_type, target=target, unit=unit)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc


def _validate_date_range(
    start_date,
    end_date,
) -> None:
    if end_date is not None and end_date <= start_date:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_date must be after start_date",
        )


async def create_tracker(
    session: AsyncSession, user: User, data: TrackerCreate
) -> Tracker:
    resolved_schedule_id = await resolve_entity_schedule_id(
        session,
        user,
        schedule_id=data.schedule_id,
        schedule=data.schedule,
    )
    if resolved_schedule_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="tracker requires schedule_id or schedule",
        )
    await assert_schedule_recurring(session, user, resolved_schedule_id)
    await assert_goal_owned(session, data.goal_id, user.id)

    tracker = Tracker(
        user_id=user.id,
        name=data.name,
        description=data.description,
        icon=data.icon,
        color=data.color,
        goal_id=data.goal_id,
        schedule_id=resolved_schedule_id,
        start_date=data.start_date,
        end_date=data.end_date,
        check_in_type=data.check_in_type.value,
        target=data.target,
        unit=data.unit,
        habit_direction=data.habit_direction.value,
    )
    session.add(tracker)
    await session.flush()
    await session.refresh(tracker)
    return tracker


async def list_trackers(
    session: AsyncSession,
    user: User,
    *,
    limit: int = 50,
    offset: int = 0,
    updated_since=None,
) -> tuple[list[Tracker], int]:
    limit, offset = clamp_pagination(limit, offset)
    base = select(Tracker).where(Tracker.user_id == user.id)
    base = apply_list_filters(base, Tracker, updated_since=updated_since)
    count_stmt = select(func.count()).select_from(Tracker).where(
        Tracker.user_id == user.id
    )
    count_stmt = apply_list_filters(count_stmt, Tracker, updated_since=updated_since)
    total = (await session.execute(count_stmt)).scalar_one()
    result = await session.execute(
        base.order_by(Tracker.id).limit(limit).offset(offset)
    )
    return list(result.scalars().all()), total


async def update_tracker(
    session: AsyncSession, user: User, tracker_id: int, data: TrackerUpdate
) -> Tracker:
    tracker = await _load_tracker(session, tracker_id, user.id)
    await apply_entity_schedule_update(session, user, tracker, data)
    if tracker.schedule_id:
        await assert_schedule_recurring(session, user, tracker.schedule_id)

    if "goal_id" in data.model_fields_set:
        await assert_goal_owned(session, data.goal_id, user.id)

    updates = data.model_dump(
        exclude_unset=True,
        exclude={"schedule", "schedule_id"},
    )
    for key, value in updates.items():
        if hasattr(value, "value"):
            setattr(tracker, key, value.value)
        else:
            setattr(tracker, key, value)

    check_in_type = CheckInType(tracker.check_in_type)
    _validate_merged_type_fields(
        check_in_type, target=tracker.target, unit=tracker.unit
    )
    _validate_date_range(tracker.start_date, tracker.end_date)

    await session.flush()
    await session.refresh(tracker)
    return tracker


async def delete_tracker(session: AsyncSession, user: User, tracker_id: int) -> None:
    tracker = await get_tracker(session, user, tracker_id)
    await soft_delete(tracker)
