from datetime import UTC, datetime

from sqlalchemy import select

from app.models.schedule import Schedule
from app.services.schedule_service import schedule_to_response
from app.services.sync_service import apply_updated_since_filter


def _schedule(**kwargs) -> Schedule:
    defaults = dict(
        id=1,
        user_id=1,
        dtstart=datetime(2026, 6, 1, 9, 0, tzinfo=UTC),
        timezone="UTC",
        rrule="FREQ=DAILY;INTERVAL=1",
        created_at=datetime(2026, 6, 1, tzinfo=UTC),
        updated_at=datetime(2026, 6, 1, tzinfo=UTC),
        specific_dates=[],
        exclusions=[],
        overrides=[],
    )
    defaults.update(kwargs)
    return Schedule(**defaults)


def test_schedule_to_response_includes_is_recurring():
    response = schedule_to_response(_schedule())
    payload = response.model_dump(mode="json")
    assert payload["is_recurring"] is True

def test_apply_updated_since_filter_full_sync_excludes_deleted():
    stmt = select(Schedule).where(Schedule.user_id == 1)
    filtered = apply_updated_since_filter(stmt, Schedule, since=None)
    compiled = str(filtered.compile(compile_kwargs={"literal_binds": True}))
    assert "deleted_at IS NULL" in compiled


def test_apply_updated_since_filter_incremental():
    since = datetime(2026, 6, 30, 15, 0, tzinfo=UTC)
    stmt = select(Schedule).where(Schedule.user_id == 1)
    filtered = apply_updated_since_filter(stmt, Schedule, since=since)
    compiled = str(filtered.compile(compile_kwargs={"literal_binds": True}))
    assert "updated_at >" in compiled
    assert "deleted_at >" in compiled
