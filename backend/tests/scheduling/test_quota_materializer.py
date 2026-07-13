from datetime import UTC, datetime

from app.models.goal_check_in import GoalCheckIn
from app.scheduling.quota_materializer import (
    _create_quota_slot,
    compute_quota_display_at,
    quota_check_in_failed,
)
from app.services.check_in_slot_helpers import (
    SLOT_KIND_ACTIVE,
    SLOT_KIND_FAILED,
    SLOT_KIND_LOCKED,
)


def _slot(**kwargs: object) -> GoalCheckIn:
    defaults = {
        "id": 1,
        "goal_id": 1,
        "check_in_at": datetime(2026, 5, 19, 9, 0, tzinfo=UTC),
        "spawned_at": datetime(2026, 5, 19, 9, 0, tzinfo=UTC),
        "slot_kind": SLOT_KIND_ACTIVE,
    }
    defaults.update(kwargs)
    return GoalCheckIn(**defaults)  # type: ignore[arg-type]


def test_failed_slot_displays_on_period_end():
    period_end = datetime(2026, 5, 31, 9, 0, tzinfo=UTC)
    slot = _slot(slot_kind=SLOT_KIND_FAILED, locked_at=period_end)
    display = compute_quota_display_at(
        slot,
        period_end_at=period_end,
        timezone="UTC",
        now=datetime(2026, 6, 1, tzinfo=UTC),
    )
    assert display == period_end


def test_locked_slot_anchors_to_locked_at():
    locked = datetime(2026, 5, 28, 9, 0, tzinfo=UTC)
    period_end = datetime(2026, 5, 31, 9, 0, tzinfo=UTC)
    slot = _slot(slot_kind=SLOT_KIND_LOCKED, locked_at=locked)
    display = compute_quota_display_at(
        slot,
        period_end_at=period_end,
        timezone="UTC",
        now=datetime(2026, 5, 30, tzinfo=UTC),
    )
    assert display == locked


def test_active_slot_drifts_to_today():
    period_end = datetime(2026, 5, 31, 9, 0, tzinfo=UTC)
    slot = _slot(
        spawned_at=datetime(2026, 5, 19, 9, 0, tzinfo=UTC),
        slot_kind=SLOT_KIND_ACTIVE,
    )
    now = datetime(2026, 5, 25, 15, 0, tzinfo=UTC)
    display = compute_quota_display_at(
        slot,
        period_end_at=period_end,
        timezone="UTC",
        now=now,
    )
    assert display == datetime(2026, 5, 25, 9, 0, tzinfo=UTC)


def test_quota_slot_check_in_at_unique_per_index():
    period_end = datetime(2026, 5, 31, 9, 0, tzinfo=UTC)
    slots = [
        _create_quota_slot(
            GoalCheckIn,
            parent_fk_name="goal_id",
            parent_id=1,
            period_start_at=datetime(2026, 5, 19, 9, 0, tzinfo=UTC),
            slot_index=index,
            spawned_at=period_end,
            slot_kind=SLOT_KIND_FAILED,
            locked_at=period_end,
        )
        for index in range(1, 4)
    ]
    check_in_ats = [slot.check_in_at for slot in slots]
    assert len(check_in_ats) == len(set(check_in_ats))


def test_quota_check_in_failed_helper():
    assert quota_check_in_failed(_slot(slot_kind=SLOT_KIND_FAILED)) is True
    assert quota_check_in_failed(_slot(slot_kind=SLOT_KIND_ACTIVE)) is False
