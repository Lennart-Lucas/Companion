from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.models.goal import GoalDirection, GoalType
from app.schemas.goal import GoalCreate, GoalUpdate
from app.schemas.goal_check_in import GoalCheckInUpdate
from app.schemas.goal_milestone import MilestoneCreate
from app.schemas.schedule import ScheduleCreate

_DT = datetime(2026, 5, 21, 9, 0, tzinfo=ZoneInfo("UTC"))
_DAILY = ScheduleCreate(dtstart=_DT, timezone="UTC", rrule="FREQ=DAILY;INTERVAL=1")
_WEEKLY = ScheduleCreate(dtstart=_DT, timezone="UTC", rrule="FREQ=WEEKLY;INTERVAL=1")
_ONE_OFF = ScheduleCreate(dtstart=_DT, timezone="UTC")


class TestGoalCreateValidation:
    def test_requires_schedule(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Books",
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("12"),
                unit="books",
                direction=GoalDirection.increasing,
            )

    def test_schedule_id_and_inline_rejected(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Books",
                schedule_id=1,
                schedule=_DAILY,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("12"),
                unit="books",
                direction=GoalDirection.increasing,
            )

    def test_non_recurring_schedule_rejected(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Once",
                schedule=_ONE_OFF,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.task,
                target=Decimal("1"),
                unit="step",
                direction=GoalDirection.increasing,
            )

    def test_target_must_be_positive(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Bad",
                schedule_id=1,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("0"),
                unit="books",
                direction=GoalDirection.increasing,
            )

    def test_unit_cannot_be_empty(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Bad",
                schedule_id=1,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("12"),
                unit="   ",
                direction=GoalDirection.increasing,
            )

    def test_end_date_after_start_date(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Short",
                schedule_id=1,
                start_date=datetime(2026, 6, 1, tzinfo=ZoneInfo("UTC")),
                end_date=datetime(2026, 5, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.pulse,
                target=Decimal("10"),
                unit="score",
                direction=GoalDirection.decreasing,
            )

    def test_valid_goal_with_milestones(self):
        goal = GoalCreate(
            name="Books",
            schedule=_WEEKLY,
            start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
            goal_type=GoalType.count,
            target=Decimal("12"),
            unit="books",
            direction=GoalDirection.increasing,
            milestones=[
                MilestoneCreate(value=Decimal("6"), name="Halfway", sort_order=0)
            ],
        )
        assert len(goal.milestones) == 1

    def test_rejects_milestone_at_target(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Books",
                schedule=_WEEKLY,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("12"),
                unit="books",
                direction=GoalDirection.increasing,
                milestones=[MilestoneCreate(value=Decimal("12"), sort_order=0)],
            )

    def test_rejects_decreasing_milestone_below_target(self):
        with pytest.raises(ValidationError):
            GoalCreate(
                name="Screen time",
                schedule=_WEEKLY,
                start_date=datetime(2026, 1, 1, tzinfo=ZoneInfo("UTC")),
                goal_type=GoalType.count,
                target=Decimal("2"),
                unit="hours",
                direction=GoalDirection.decreasing,
                milestones=[MilestoneCreate(value=Decimal("1"), sort_order=0)],
            )


class TestGoalCheckInUpdate:
    def test_requires_exactly_one_field(self):
        with pytest.raises(ValidationError):
            GoalCheckInUpdate()

    def test_accepts_count_value(self):
        body = GoalCheckInUpdate(count_value=Decimal("4"))
        assert body.count_value == Decimal("4")
