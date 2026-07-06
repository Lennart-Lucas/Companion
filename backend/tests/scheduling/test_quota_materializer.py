from datetime import UTC, date, datetime

from app.models.check_in_scheduling import (
    CheckInMode,
    QuotaPeriodUnit,
    SlotKind,
)
from app.models.tracker import CheckInType, HabitDirection, Tracker
from app.models.tracker_check_in import TrackerCheckIn
from app.scheduling.quota_materializer import (
    compute_display_at,
    entity_uses_quota_mode,
    lock_check_in_on_log,
)
from app.scheduling.quota_periods import local_date


def _quota_tracker(*, start: datetime) -> Tracker:
    return Tracker(
        id=1,
        user_id=1,
        schedule_id=1,
        name="Gym",
        start_date=start,
        end_date=None,
        check_in_type=CheckInType.task.value,
        habit_direction=HabitDirection.build.value,
        check_in_mode=CheckInMode.times_per_period.value,
        quota_times=3,
        quota_period_interval=1,
        quota_period_unit=QuotaPeriodUnit.weeks.value,
    )


class TestQuotaMaterializerHelpers:
    def test_entity_uses_quota_mode(self):
        tracker = _quota_tracker(start=datetime(2026, 1, 5, 9, tzinfo=UTC))
        assert entity_uses_quota_mode(tracker) is True

    def test_lock_check_in_sets_locked_fields(self):
        tracker = _quota_tracker(start=datetime(2026, 1, 5, 9, tzinfo=UTC))
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=datetime(2026, 1, 5, 9, tzinfo=UTC),
            spawned_at=datetime(2026, 1, 5, 9, tzinfo=UTC),
            slot_kind=SlotKind.active.value,
        )
        lock_check_in_on_log(
            check_in,
            tracker,
            now=datetime(2026, 1, 7, 10, 30, tzinfo=UTC),
        )
        assert check_in.slot_kind == SlotKind.locked.value
        assert check_in.locked_at is not None
        assert local_date(check_in.check_in_at) == date(2026, 1, 7)

    def test_active_check_in_floats_display_to_today(self):
        spawned = datetime(2026, 1, 5, 9, tzinfo=UTC)
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=spawned,
            spawned_at=spawned,
            slot_kind=SlotKind.active.value,
        )
        display = compute_display_at(
            check_in,
            entity=_quota_tracker(start=datetime(2026, 1, 5, 9, tzinfo=UTC)),
            now=datetime(2026, 1, 10, 12, tzinfo=UTC),
        )
        assert local_date(display) == date(2026, 1, 10)

    def test_fixed_schedule_check_in_does_not_float(self):
        spawned = datetime(2026, 1, 5, 9, tzinfo=UTC)
        check_in = TrackerCheckIn(
            id=1,
            tracker_id=1,
            check_in_at=spawned,
            spawned_at=spawned,
            slot_kind=SlotKind.active.value,
        )
        tracker = Tracker(
            id=1,
            user_id=1,
            schedule_id=1,
            name="Habit",
            start_date=spawned,
            end_date=None,
            check_in_type=CheckInType.task.value,
            habit_direction=HabitDirection.build.value,
        )
        display = compute_display_at(
            check_in,
            entity=tracker,
            now=datetime(2026, 1, 10, 12, tzinfo=UTC),
        )
        assert local_date(display) == date(2026, 1, 5)
