from datetime import UTC, datetime
from decimal import Decimal

from app.models.tracker import CheckInType, HabitDirection
from app.models.tracker_check_in import TrackerCheckIn
from app.schemas.tracker_check_in import TrackerCheckInUpdate
from app.services.tracker_check_in_service import (
    _apply_check_in_log,
    _check_in_at_in_tracker_window,
    _check_in_logged,
    _check_in_to_response,
    _clip_window,
    _merge_check_ins_by_at,
)


def _sample_tracker(
    *,
    start_date: datetime,
    end_date: datetime | None = None,
    check_in_type: str = CheckInType.count.value,
) -> "Tracker":
    from app.models.tracker import Tracker

    return Tracker(
        id=1,
        user_id=1,
        schedule_id=1,
        name="Water",
        start_date=start_date,
        end_date=end_date,
        check_in_type=check_in_type,
        target=Decimal("8"),
        unit="glasses",
        habit_direction=HabitDirection.build.value,
    )


class TestClipWindow:
    def test_clips_to_tracker_start(self):
        tracker = _sample_tracker(
            start_date=datetime(2026, 5, 10, tzinfo=UTC),
            end_date=datetime(2026, 5, 31, tzinfo=UTC),
        )
        start, end = _clip_window(
            tracker,
            start=datetime(2026, 5, 1, tzinfo=UTC),
            end=datetime(2026, 5, 20, tzinfo=UTC),
        )
        assert start == datetime(2026, 5, 10, tzinfo=UTC)
        assert end == datetime(2026, 5, 20, tzinfo=UTC)

    def test_clips_to_tracker_end(self):
        tracker = _sample_tracker(
            start_date=datetime(2026, 5, 1, tzinfo=UTC),
            end_date=datetime(2026, 5, 15, tzinfo=UTC),
        )
        start, end = _clip_window(
            tracker,
            start=datetime(2026, 5, 1, tzinfo=UTC),
            end=datetime(2026, 5, 31, tzinfo=UTC),
        )
        assert start == datetime(2026, 5, 1, tzinfo=UTC)
        assert end == datetime(2026, 5, 15, tzinfo=UTC)

    def test_empty_when_query_before_tracker(self):
        tracker = _sample_tracker(
            start_date=datetime(2026, 6, 1, tzinfo=UTC),
        )
        start, end = _clip_window(
            tracker,
            start=datetime(2026, 5, 1, tzinfo=UTC),
            end=datetime(2026, 5, 10, tzinfo=UTC),
        )
        assert start == end


class TestCheckInAtInTrackerWindow:
    def test_accepts_inside_window(self):
        tracker = _sample_tracker(
            start_date=datetime(2026, 5, 1, tzinfo=UTC),
            end_date=datetime(2026, 5, 31, tzinfo=UTC),
        )
        assert _check_in_at_in_tracker_window(
            tracker, datetime(2026, 5, 15, 12, 0, tzinfo=UTC)
        )

    def test_rejects_before_start(self):
        tracker = _sample_tracker(start_date=datetime(2026, 5, 10, tzinfo=UTC))
        assert not _check_in_at_in_tracker_window(
            tracker, datetime(2026, 5, 9, tzinfo=UTC)
        )

    def test_rejects_after_end(self):
        tracker = _sample_tracker(
            start_date=datetime(2026, 5, 1, tzinfo=UTC),
            end_date=datetime(2026, 5, 15, tzinfo=UTC),
        )
        assert not _check_in_at_in_tracker_window(
            tracker, datetime(2026, 5, 20, tzinfo=UTC)
        )


class TestCheckInResponse:
    def test_logged_false_when_empty(self):
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
        )
        assert _check_in_logged(check_in) is False
        response = _check_in_to_response(check_in, CheckInType.task)
        assert response.logged is False
        assert response.completed is None

    def test_logged_true_when_count_set(self):
        check_in = TrackerCheckIn(
            id=2,
            tracker_id=1,
            check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
            count_value=Decimal("6"),
        )
        assert _check_in_logged(check_in) is True
        response = _check_in_to_response(check_in, CheckInType.count)
        assert response.logged is True
        assert response.count_value == Decimal("6")

    def test_logged_true_when_skipped(self):
        check_in = TrackerCheckIn(
            id=3,
            tracker_id=1,
            check_in_at=datetime(2026, 5, 21, 9, 0, tzinfo=UTC),
            skipped=True,
        )
        assert _check_in_logged(check_in) is True
        response = _check_in_to_response(check_in, CheckInType.task)
        assert response.logged is True
        assert response.skipped is True
        assert response.completed is None


class TestMergeCheckInsByAt:
    def test_merges_distinct_times(self):
        first = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 6, 29, 10, 0, tzinfo=UTC),
        )
        second = TrackerCheckIn(
            id=2,
            tracker_id=1,
            check_in_at=datetime(2026, 6, 29, 22, 0, tzinfo=UTC),
        )
        merged = _merge_check_ins_by_at([second], [first])
        assert [c.id for c in merged] == [1, 2]

    def test_later_group_wins_same_instant(self):
        scheduled = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 6, 29, 10, 0, tzinfo=UTC),
        )
        stored = TrackerCheckIn(
            id=9,
            tracker_id=1,
            check_in_at=datetime(2026, 6, 29, 10, 0, tzinfo=UTC),
            count_value=Decimal("3"),
        )
        merged = _merge_check_ins_by_at([scheduled], [stored])
        assert len(merged) == 1
        assert merged[0].id == 9


class TestDurationTimer:
    def test_timer_started_does_not_count_as_logged(self):
        started = datetime(2026, 7, 3, 10, 0, tzinfo=UTC)
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 7, 3, 9, 0, tzinfo=UTC),
            timer_started_at=started,
        )
        assert _check_in_logged(check_in) is False
        response = _check_in_to_response(check_in, CheckInType.duration)
        assert response.timer_started_at == started
        assert response.logged is False

    def test_start_timer_sets_timer_started_at(self):
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 7, 3, 9, 0, tzinfo=UTC),
        )
        started = datetime(2026, 7, 3, 10, 15, tzinfo=UTC)
        _apply_check_in_log(
            check_in,
            CheckInType.duration,
            TrackerCheckInUpdate(timer_started_at=started),
        )
        assert check_in.timer_started_at == started
        assert check_in.value_seconds is None

    def test_stop_timer_sets_value_seconds_and_clears_timer(self):
        started = datetime(2026, 7, 3, 10, 0, tzinfo=UTC)
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 7, 3, 9, 0, tzinfo=UTC),
            value_seconds=300,
            timer_started_at=started,
        )
        _apply_check_in_log(
            check_in,
            CheckInType.duration,
            TrackerCheckInUpdate(value_seconds=900),
        )
        assert check_in.value_seconds == 900
        assert check_in.timer_started_at is None
        assert _check_in_logged(check_in) is True

    def test_skip_clears_timer_started_at(self):
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 7, 3, 9, 0, tzinfo=UTC),
            value_seconds=120,
            timer_started_at=datetime(2026, 7, 3, 10, 0, tzinfo=UTC),
        )
        _apply_check_in_log(
            check_in,
            CheckInType.duration,
            TrackerCheckInUpdate(skipped=True),
        )
        assert check_in.skipped is True
        assert check_in.timer_started_at is None
        assert check_in.value_seconds is None
