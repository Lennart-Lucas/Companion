import os
from datetime import UTC, datetime

import pytest
from zoneinfo import ZoneInfo

from app.models.schedule import Schedule
from app.models.task import Task, TaskPriority, TaskStatus
from app.services.task_occurrence_service import _clip_window, task_is_recurring


class TestTaskIsRecurring:
    def _task(self, **kwargs) -> Task:
        defaults = {
            "user_id": 1,
            "name": "Test",
            "status": TaskStatus.pending.value,
            "priority": TaskPriority.medium.value,
        }
        defaults.update(kwargs)
        return Task(**defaults)

    def test_no_schedule(self):
        task = self._task(schedule_id=None)
        assert task_is_recurring(task) is False

    def test_schedule_id_without_loaded_relation(self):
        task = self._task(schedule_id=1)
        assert task_is_recurring(task) is True

    def test_schedule_none_repeat(self):
        schedule = Schedule(
            user_id=1,
            dtstart=datetime.now(UTC),
            timezone="UTC",
        )
        task = self._task(schedule_id=1)
        task.schedule = schedule
        assert task_is_recurring(task) is False

    def test_schedule_daily(self):
        schedule = Schedule(
            user_id=1,
            dtstart=datetime.now(UTC),
            timezone="UTC",
            rrule="FREQ=DAILY;INTERVAL=1",
        )
        task = self._task(schedule_id=1)
        task.schedule = schedule
        assert task_is_recurring(task) is True


class TestClipWindow:
    def _schedule(self, **kwargs) -> Schedule:
        defaults = {
            "user_id": 1,
            "dtstart": datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
            "timezone": "UTC",
            "rrule": "FREQ=DAILY;INTERVAL=1",
        }
        defaults.update(kwargs)
        return Schedule(**defaults)

    def test_no_schedule_dates_uses_query_window(self):
        schedule = self._schedule()
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)
        window_start, window_end = _clip_window(schedule, start=start, end=end)
        assert window_start == start
        assert window_end == end

    def test_schedule_start_clips_query(self):
        schedule = self._schedule(
            start_date=datetime(2026, 5, 23, tzinfo=UTC),
        )
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)
        window_start, window_end = _clip_window(schedule, start=start, end=end)
        assert window_start == datetime(2026, 5, 23, tzinfo=UTC)
        assert window_end == end

    def test_schedule_end_clips_query(self):
        schedule = self._schedule(
            end_date=datetime(2026, 5, 22, tzinfo=UTC),
        )
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)
        window_start, window_end = _clip_window(schedule, start=start, end=end)
        assert window_start == start
        assert window_end == datetime(2026, 5, 22, tzinfo=UTC)

    def test_empty_window_when_start_after_end(self):
        schedule = self._schedule(
            start_date=datetime(2026, 6, 1, tzinfo=UTC),
        )
        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)
        window_start, window_end = _clip_window(schedule, start=start, end=end)
        assert window_start == datetime(2026, 6, 1, tzinfo=UTC)
        assert window_end == datetime(2026, 6, 1, tzinfo=UTC)


@pytest.mark.skipif(
    os.environ.get("RUN_INTEGRATION_TESTS") != "1",
    reason="Set RUN_INTEGRATION_TESTS=1 and a running Postgres to run DB tests",
)
@pytest.mark.asyncio
async def test_subtask_toggle_independent_per_occurrence():
    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.database import async_session_factory
    from app.models.task_occurrence import TaskOccurrence
    from app.models.task_occurrence_subtask import TaskOccurrenceSubtask
    from app.models.user import User
    from app.schemas.schedule import ScheduleCreate
    from app.schemas.task import TaskCreate
    from app.schemas.task_occurrence import SubtaskTemplateCreate
    from app.services import task_occurrence_service, task_service

    async with async_session_factory() as session:
        user = (
            await session.execute(select(User).limit(1))
        ).scalar_one_or_none()
        if user is None:
            pytest.skip("No users in database — register via API first")

        task = await task_service.create_task(
            session,
            user,
            TaskCreate(
                name="Integration recurring task",
                schedule=ScheduleCreate(
                    dtstart=datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC")),
                    timezone="UTC",
                    rrule="FREQ=DAILY;INTERVAL=1",
                ),
                subtasks=[
                    SubtaskTemplateCreate(title="Checklist item", sort_order=0)
                ],
            ),
        )
        await session.commit()

        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 23, tzinfo=UTC)
        occurrences = await task_occurrence_service.list_occurrences(
            session, user, task.id, start=start, end=end, max_count=10
        )
        await session.commit()
        assert len(occurrences) >= 2

        occ_a, occ_b = occurrences[0], occurrences[1]
        subtask_id = occ_a.subtasks[0].id

        await task_occurrence_service.toggle_occurrence_subtask(
            session,
            user,
            task.id,
            occ_a.id,
            subtask_id,
            completed=True,
        )
        await session.commit()

        refreshed = await task_occurrence_service.list_occurrences(
            session, user, task.id, start=start, end=end, max_count=10
        )
        by_id = {o.id: o for o in refreshed}
        assert by_id[occ_a.id].subtasks[0].completed is True
        assert by_id[occ_b.id].subtasks[0].completed is False

        await task_service.delete_task(session, user, task.id)
        await session.commit()


@pytest.mark.skipif(
    os.environ.get("RUN_INTEGRATION_TESTS") != "1",
    reason="Set RUN_INTEGRATION_TESTS=1 and a running Postgres to run DB tests",
)
@pytest.mark.asyncio
async def test_existing_only_does_not_materialize():
    from sqlalchemy import func, select

    from app.database import async_session_factory
    from app.models.task_occurrence import TaskOccurrence
    from app.models.user import User
    from app.schemas.schedule import ScheduleCreate
    from app.schemas.task import TaskCreate
    from app.services import task_occurrence_service, task_service

    async with async_session_factory() as session:
        user = (
            await session.execute(select(User).limit(1))
        ).scalar_one_or_none()
        if user is None:
            pytest.skip("No users in database — register via API first")

        task = await task_service.create_task(
            session,
            user,
            TaskCreate(
                name="Virtual list task",
                schedule=ScheduleCreate(
                    dtstart=datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC")),
                    timezone="UTC",
                    rrule="FREQ=DAILY;INTERVAL=1",
                ),
            ),
        )
        await session.commit()

        start = datetime(2026, 5, 21, tzinfo=UTC)
        end = datetime(2026, 5, 25, tzinfo=UTC)

        count_before = (
            await session.execute(
                select(func.count())
                .select_from(TaskOccurrence)
                .where(TaskOccurrence.task_id == task.id)
            )
        ).scalar_one()

        existing = await task_occurrence_service.list_occurrences(
            session,
            user,
            task.id,
            start=start,
            end=end,
            existing_only=True,
        )
        count_after = (
            await session.execute(
                select(func.count())
                .select_from(TaskOccurrence)
                .where(TaskOccurrence.task_id == task.id)
            )
        ).scalar_one()

        assert existing == []
        assert count_after == count_before

        materialized = await task_occurrence_service.list_occurrences(
            session, user, task.id, start=start, end=end, max_count=10
        )
        assert len(materialized) >= 3

        await task_service.delete_task(session, user, task.id)
        await session.commit()


@pytest.mark.skipif(
    os.environ.get("RUN_INTEGRATION_TESTS") != "1",
    reason="Set RUN_INTEGRATION_TESTS=1 and a running Postgres to run DB tests",
)
@pytest.mark.asyncio
async def test_ensure_occurrence_is_idempotent():
    from sqlalchemy import select

    from app.database import async_session_factory
    from app.models.user import User
    from app.schemas.schedule import ScheduleCreate
    from app.schemas.task import TaskCreate
    from app.services import task_occurrence_service, task_service

    async with async_session_factory() as session:
        user = (
            await session.execute(select(User).limit(1))
        ).scalar_one_or_none()
        if user is None:
            pytest.skip("No users in database — register via API first")

        task = await task_service.create_task(
            session,
            user,
            TaskCreate(
                name="Ensure occurrence task",
                schedule=ScheduleCreate(
                    dtstart=datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC")),
                    timezone="UTC",
                    rrule="FREQ=DAILY;INTERVAL=1",
                ),
            ),
        )
        await session.commit()

        at = datetime(2026, 5, 22, 9, 0, tzinfo=ZoneInfo("UTC"))
        first = await task_occurrence_service.ensure_occurrence(
            session, user, task.id, occurrence_at=at
        )
        second = await task_occurrence_service.ensure_occurrence(
            session, user, task.id, occurrence_at=at
        )
        await session.commit()

        assert first.id == second.id
        assert first.occurrence_at == second.occurrence_at

        await task_service.delete_task(session, user, task.id)
        await session.commit()
