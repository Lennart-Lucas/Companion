"""Helpers for optional check-in slot columns (legacy productivity schema)."""

from datetime import UTC, datetime

SLOT_KIND_ACTIVE = "active"
SLOT_KIND_LOCKED = "locked"


def materialization_fields(check_in_at: datetime) -> dict[str, object]:
    """Kwargs for new materialized check-ins when slot columns exist."""
    at = check_in_at
    return {
        "spawned_at": at,
        "slot_kind": SLOT_KIND_ACTIVE,
    }


def lock_check_in_slot(check_in: object) -> None:
    """Mark a check-in slot locked after the user logs or skips."""
    check_in.slot_kind = SLOT_KIND_LOCKED  # type: ignore[attr-defined]
    if getattr(check_in, "locked_at", None) is None:
        check_in.locked_at = datetime.now(UTC)  # type: ignore[attr-defined]
