from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.models.task import TaskPriority, TaskStatus
from app.schemas.schedule import ScheduleCreate
from app.schemas.task import TaskCreate, TaskUpdate
from app.schemas.task_occurrence import SubtaskTemplateCreate

_DT = datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC"))


class TestTaskScheduleValidation:
    def test_schedule_id_and_inline_rejected(self):
        with pytest.raises(ValidationError):
            TaskCreate(
                name="Test",
                schedule_id=1,
                schedule=ScheduleCreate(
                    dtstart=_DT,
                    timezone="UTC",
                ),
            )

    def test_inline_schedule_allowed(self):
        task = TaskCreate(
            name="Repeating",
            schedule=ScheduleCreate(
                dtstart=_DT,
                timezone="UTC",
                rrule="FREQ=DAILY;INTERVAL=1",
            ),
            subtasks=[SubtaskTemplateCreate(title="Step one", sort_order=0)],
        )
        assert task.schedule is not None
        assert len(task.subtasks) == 1

    def test_status_priority_defaults(self):
        task = TaskCreate(name="Defaults")
        assert task.status == TaskStatus.pending
        assert task.priority == TaskPriority.medium

    def test_planned_at_before_deadline(self):
        task = TaskCreate(
            name="Planned",
            planned_at=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
            deadline=datetime(2026, 5, 5, tzinfo=ZoneInfo("UTC")),
        )
        assert task.planned_at is not None

    def test_planned_after_deadline_rejected(self):
        with pytest.raises(ValidationError):
            TaskCreate(
                name="Invalid",
                planned_at=datetime(2026, 5, 10, tzinfo=ZoneInfo("UTC")),
                deadline=datetime(2026, 5, 5, tzinfo=ZoneInfo("UTC")),
            )


class TestScheduleDateValidation:
    def test_optional_start_end_allowed(self):
        schedule = ScheduleCreate(
            dtstart=_DT,
            timezone="UTC",
            rrule="FREQ=DAILY;INTERVAL=1",
            start_date=datetime(2026, 6, 1, tzinfo=ZoneInfo("UTC")),
            end_date=datetime(2026, 12, 1, tzinfo=ZoneInfo("UTC")),
        )
        assert schedule.start_date is not None

    def test_end_before_start_rejected(self):
        with pytest.raises(ValidationError):
            ScheduleCreate(
                dtstart=_DT,
                timezone="UTC",
                rrule="FREQ=DAILY;INTERVAL=1",
                start_date=datetime(2026, 12, 1, tzinfo=ZoneInfo("UTC")),
                end_date=datetime(2026, 6, 1, tzinfo=ZoneInfo("UTC")),
            )
