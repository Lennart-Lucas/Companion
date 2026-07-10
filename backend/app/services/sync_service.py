from datetime import UTC, datetime

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event
from app.models.goal import Goal
from app.models.media_title import MediaTitle
from app.models.project import Project
from app.models.schedule import Schedule
from app.models.task import Task
from app.models.tracker import Tracker
from app.models.user import User
from app.schemas.event import EventResponse
from app.schemas.goal import GoalResponse
from app.schemas.media_title import MediaTitleResponse
from app.schemas.project import ProjectResponse
from app.services.schedule_service import schedule_to_response
from app.schemas.task import TaskResponse
from app.schemas.tracker import TrackerResponse
from app.services.task_service import task_to_response


def _ensure_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


async def get_sync_changes(
    session: AsyncSession,
    user: User,
    *,
    since: datetime | None,
) -> dict:
    since_utc = _ensure_utc(since) if since is not None else None
    now = datetime.now(UTC)

    upserts: dict[str, list] = {
        "schedules": [],
        "events": [],
        "media_titles": [],
        "goals": [],
        "trackers": [],
        "projects": [],
        "tasks": [],
    }
    tombstones: dict[str, list[str]] = {
        "schedules": [],
        "events": [],
        "media_titles": [],
        "goals": [],
        "trackers": [],
        "projects": [],
        "tasks": [],
    }

    await _collect_schedules(session, user, since_utc, upserts, tombstones)
    await _collect_events(session, user, since_utc, upserts, tombstones)
    await _collect_media_titles(session, user, since_utc, upserts, tombstones)
    await _collect_goals(session, user, since_utc, upserts, tombstones)
    await _collect_trackers(session, user, since_utc, upserts, tombstones)
    await _collect_projects(session, user, since_utc, upserts, tombstones)
    await _collect_tasks(session, user, since_utc, upserts, tombstones)

    return {
        "since": since_utc,
        "server_time": now,
        "upserts": upserts,
        "tombstones": tombstones,
    }


async def _collect_schedules(session, user, since, upserts, tombstones):
    stmt = select(Schedule).where(Schedule.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Schedule, since)
    result = await session.execute(
        stmt.options(
            selectinload(Schedule.specific_dates),
            selectinload(Schedule.exclusions),
            selectinload(Schedule.overrides),
        )
    )
    for schedule in result.scalars().all():
        if schedule.deleted_at is not None:
            tombstones["schedules"].append(str(schedule.id))
        else:
            upserts["schedules"].append(
                schedule_to_response(schedule).model_dump(mode="json")
            )


async def _collect_events(session, user, since, upserts, tombstones):
    stmt = select(Event).where(Event.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Event, since)
    result = await session.execute(stmt)
    for event in result.scalars().all():
        if event.deleted_at is not None:
            tombstones["events"].append(str(event.id))
        else:
            upserts["events"].append(
                EventResponse.model_validate(event).model_dump(mode="json")
            )


async def _collect_media_titles(session, user, since, upserts, tombstones):
    stmt = select(MediaTitle).where(MediaTitle.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, MediaTitle, since)
    result = await session.execute(stmt)
    for media_title in result.scalars().all():
        if media_title.deleted_at is not None:
            tombstones["media_titles"].append(str(media_title.id))
        else:
            upserts["media_titles"].append(
                MediaTitleResponse.model_validate(media_title).model_dump(mode="json")
            )


async def _collect_goals(session, user, since, upserts, tombstones):
    stmt = select(Goal).where(Goal.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Goal, since)
    result = await session.execute(stmt.options(selectinload(Goal.milestones)))
    for goal in result.scalars().all():
        if goal.deleted_at is not None:
            tombstones["goals"].append(str(goal.id))
        else:
            upserts["goals"].append(
                GoalResponse.model_validate(goal).model_dump(mode="json")
            )


async def _collect_trackers(session, user, since, upserts, tombstones):
    stmt = select(Tracker).where(Tracker.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Tracker, since)
    result = await session.execute(stmt)
    for tracker in result.scalars().all():
        if tracker.deleted_at is not None:
            tombstones["trackers"].append(str(tracker.id))
        else:
            upserts["trackers"].append(
                TrackerResponse.model_validate(tracker).model_dump(mode="json")
            )


async def _collect_projects(session, user, since, upserts, tombstones):
    stmt = select(Project).where(Project.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Project, since)
    result = await session.execute(stmt)
    for project in result.scalars().all():
        if project.deleted_at is not None:
            tombstones["projects"].append(str(project.id))
        else:
            upserts["projects"].append(
                ProjectResponse.model_validate(project).model_dump(mode="json")
            )


async def _collect_tasks(session, user, since, upserts, tombstones):
    stmt = select(Task).where(Task.user_id == user.id)
    stmt = apply_updated_since_filter(stmt, Task, since)
    result = await session.execute(
        stmt.options(
            selectinload(Task.subtask_templates),
            selectinload(Task.schedule),
        )
    )
    for task in result.scalars().all():
        if task.deleted_at is not None:
            tombstones["tasks"].append(str(task.id))
        else:
            upserts["tasks"].append(
                task_to_response(task).model_dump(mode="json")
            )


def apply_updated_since_filter(stmt, model, since: datetime | None):
    if since is None:
        return stmt.where(model.deleted_at.is_(None))
    since_utc = _ensure_utc(since)
    return stmt.where(
        or_(
            model.deleted_at.is_(None),
            model.deleted_at > since_utc,
        ),
        or_(
            model.updated_at > since_utc,
            model.deleted_at > since_utc,
        ),
    )
