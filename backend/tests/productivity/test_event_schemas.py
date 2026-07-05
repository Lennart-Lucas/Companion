from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.schemas.event import EventCreate, EventUpdate
from app.schemas.schedule import ScheduleCreate


class TestEventSchemas:
    def test_start_at_required(self):
        with pytest.raises(ValidationError):
            EventCreate(name="Meetup")

    def test_valid_create(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        end = datetime(2026, 7, 1, 10, 0, tzinfo=ZoneInfo("UTC"))
        event = EventCreate(name="Standup", start_at=start, end_at=end)
        assert event.name == "Standup"
        assert event.start_at == start
        assert event.end_at == end

    def test_end_at_must_be_after_start_at(self):
        start = datetime(2026, 7, 1, 10, 0, tzinfo=ZoneInfo("UTC"))
        end = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        with pytest.raises(ValidationError):
            EventCreate(name="Invalid", start_at=start, end_at=end)

    def test_end_at_equal_to_start_at_rejected(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        with pytest.raises(ValidationError):
            EventCreate(name="Invalid", start_at=start, end_at=start)

    def test_end_at_optional(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        event = EventCreate(name="Open-ended", start_at=start)
        assert event.end_at is None

    def test_name_must_not_be_empty(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        with pytest.raises(ValidationError):
            EventCreate(name="   ", start_at=start)

    def test_color_must_be_hex(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        with pytest.raises(ValidationError):
            EventCreate(name="Colored", start_at=start, color="red")

    def test_update_name_optional(self):
        update = EventUpdate(description="Updated notes")
        assert update.name is None
        assert update.description == "Updated notes"

    def test_schedule_id_and_inline_rejected_on_create(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        with pytest.raises(ValidationError):
            EventCreate(
                name="Recurring",
                start_at=start,
                schedule_id=1,
                schedule=ScheduleCreate(
                    dtstart=start,
                    timezone="UTC",
                    rrule="FREQ=DAILY;INTERVAL=1",
                ),
            )

    def test_inline_schedule_allowed_on_create(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        event = EventCreate(
            name="Weekly sync",
            start_at=start,
            schedule=ScheduleCreate(
                dtstart=start,
                timezone="UTC",
                rrule="FREQ=WEEKLY;INTERVAL=1",
            ),
        )
        assert event.schedule is not None
        assert event.schedule_id is None

    def test_schedule_id_only_allowed_on_create(self):
        start = datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC"))
        event = EventCreate(name="Linked", start_at=start, schedule_id=42)
        assert event.schedule_id == 42
        assert event.schedule is None

    def test_update_rejects_both_schedule_fields(self):
        with pytest.raises(ValidationError):
            EventUpdate(
                schedule_id=1,
                schedule=ScheduleCreate(
                    dtstart=datetime(2026, 7, 1, 9, 0, tzinfo=ZoneInfo("UTC")),
                    timezone="UTC",
                    rrule="FREQ=DAILY;INTERVAL=1",
                ),
            )

    def test_update_can_clear_schedule(self):
        update = EventUpdate(schedule_id=None)
        assert update.schedule_id is None
