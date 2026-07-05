from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.models.tracker import CheckInType, HabitDirection
from app.schemas.schedule import ScheduleCreate
from app.schemas.tracker import TrackerCreate, TrackerUpdate
from app.schemas.tracker_check_in import TrackerCheckInCreate, TrackerCheckInUpdate

_DT = datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC"))
_DAILY = ScheduleCreate(dtstart=_DT, timezone="UTC", rrule="FREQ=DAILY;INTERVAL=1")
_ONE_OFF = ScheduleCreate(dtstart=_DT, timezone="UTC")


class TestTrackerCreateValidation:
    def test_requires_schedule(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Water",
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.count,
                target=Decimal("8"),
                unit="glasses",
                habit_direction=HabitDirection.build,
            )

    def test_schedule_id_and_inline_rejected(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Water",
                schedule_id=1,
                schedule=_DAILY,
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.count,
                target=Decimal("8"),
                unit="glasses",
                habit_direction=HabitDirection.build,
            )

    def test_non_recurring_schedule_rejected(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Once",
                schedule=_ONE_OFF,
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.task,
                habit_direction=HabitDirection.quit,
            )

    def test_count_requires_target_and_unit(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Water",
                schedule_id=1,
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.count,
                target=Decimal("8"),
                habit_direction=HabitDirection.build,
            )

    def test_duration_requires_target_no_unit(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Meditate",
                schedule_id=1,
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.duration,
                target=Decimal("600"),
                unit="minutes",
                habit_direction=HabitDirection.build,
            )

    def test_task_rejects_target(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Floss",
                schedule_id=1,
                start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.task,
                target=Decimal("1"),
                habit_direction=HabitDirection.build,
            )

    def test_end_date_after_start_date(self):
        with pytest.raises(ValidationError):
            TrackerCreate(
                name="Short",
                schedule_id=1,
                start_date=datetime(2026, 6, 1, tzinfo=ZoneInfo("UTC")),
                end_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                check_in_type=CheckInType.task,
                habit_direction=HabitDirection.build,
            )

    def test_valid_count_tracker(self):
        tracker = TrackerCreate(
            name="Water",
            schedule=_DAILY,
            start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
            check_in_type=CheckInType.count,
            target=Decimal("8"),
            unit="glasses",
            habit_direction=HabitDirection.build,
        )
        assert tracker.unit == "glasses"

    def test_optional_goal_id(self):
        tracker = TrackerCreate(
            name="Water",
            goal_id=42,
            schedule_id=1,
            start_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
            check_in_type=CheckInType.task,
            habit_direction=HabitDirection.build,
        )
        assert tracker.goal_id == 42


class TestTrackerCheckInUpdate:
    def test_requires_exactly_one_field(self):
        with pytest.raises(ValidationError):
            TrackerCheckInUpdate()

        with pytest.raises(ValidationError):
            TrackerCheckInUpdate(completed=True, count_value=Decimal("1"))

    def test_accepts_completed(self):
        body = TrackerCheckInUpdate(completed=True)
        assert body.completed is True

    def test_accepts_skipped(self):
        body = TrackerCheckInUpdate(skipped=True)
        assert body.skipped is True

    def test_accepts_timer_started_at(self):
        started = datetime(2026, 7, 3, 10, 0, tzinfo=ZoneInfo("UTC"))
        body = TrackerCheckInUpdate(timer_started_at=started)
        assert body.timer_started_at == started

    def test_rejects_skipped_false(self):
        with pytest.raises(ValidationError):
            TrackerCheckInUpdate(skipped=False)


class TestTrackerCheckInCreate:
    def test_requires_check_in_at_and_log_field(self):
        with pytest.raises(ValidationError):
            TrackerCheckInCreate(
                check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC")),
            )

    def test_accepts_count_create(self):
        body = TrackerCheckInCreate(
            check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC")),
            count_value=Decimal("6"),
        )
        assert body.count_value == Decimal("6")
