from datetime import UTC, datetime
from decimal import Decimal

from app.models.goal import GoalDirection, GoalType
from app.models.goal_check_in import GoalCheckIn
from app.services.goal_check_in_service import (
    _check_in_logged,
    _check_in_to_response,
    _clip_window,
)


def _sample_goal(
    *,
    start_date: datetime,
    end_date: datetime | None = None,
    goal_type: str = GoalType.count.value,
) -> "Goal":
    from app.models.goal import Goal

    return Goal(
        id=1,
        user_id=1,
        schedule_id=1,
        name="Books",
        start_date=start_date,
        end_date=end_date,
        goal_type=goal_type,
        target=Decimal("12"),
        unit="books",
        direction=GoalDirection.increasing.value,
    )


class TestClipWindow:
    def test_clips_to_goal_start(self):
        goal = _sample_goal(
            start_date=datetime(2026, 5, 10, tzinfo=UTC),
            end_date=datetime(2026, 5, 31, tzinfo=UTC),
        )
        start, end = _clip_window(
            goal,
            start=datetime(2026, 5, 1, tzinfo=UTC),
            end=datetime(2026, 5, 20, tzinfo=UTC),
        )
        assert start == datetime(2026, 5, 10, tzinfo=UTC)
        assert end == datetime(2026, 5, 20, tzinfo=UTC)

    def test_empty_when_query_before_goal(self):
        goal = _sample_goal(start_date=datetime(2026, 6, 1, tzinfo=UTC))
        start, end = _clip_window(
            goal,
            start=datetime(2026, 5, 1, tzinfo=UTC),
            end=datetime(2026, 5, 10, tzinfo=UTC),
        )
        assert start == end


class TestCheckInResponse:
    def test_logged_with_pulse_score(self):
        check_in = GoalCheckIn(
            id=1,
            goal_id=1,
            check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
            pulse_score=7,
        )
        assert _check_in_logged(check_in) is True
        response = _check_in_to_response(check_in, GoalType.pulse)
        assert response.logged is True
        assert response.pulse_score == 7


def test_pulse_goal_type_constant():
    assert GoalType.pulse.value == "pulse"
