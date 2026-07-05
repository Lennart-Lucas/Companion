from datetime import datetime
from zoneinfo import ZoneInfo

from app.models.event import Event
from app.models.schedule import Schedule
from app.services.event_service import event_is_recurring


def _event_with_schedule(*, rrule: str | None) -> Event:
    schedule = Schedule(
        id=1,
        user_id=1,
        dtstart=datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC")),
        rrule=rrule,
        timezone="UTC",
    )
    return Event(
        id=1,
        user_id=1,
        name="Test",
        start_at=datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC")),
        schedule_id=1,
        schedule=schedule,
    )


class TestEventIsRecurring:
    def test_no_schedule_is_not_recurring(self):
        event = Event(
            id=1,
            user_id=1,
            name="One-off",
            start_at=datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC")),
        )
        assert event_is_recurring(event) is False

    def test_repeating_schedule_is_recurring(self):
        event = _event_with_schedule(rrule="FREQ=DAILY;INTERVAL=1")
        assert event_is_recurring(event) is True

    def test_no_rrule_is_not_recurring(self):
        event = _event_with_schedule(rrule=None)
        assert event_is_recurring(event) is False

    def test_schedule_id_without_loaded_schedule_assumes_recurring(self):
        event = Event(
            id=1,
            user_id=1,
            name="Linked",
            start_at=datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC")),
            schedule_id=5,
        )
        assert event_is_recurring(event) is True
