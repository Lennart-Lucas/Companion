"""Scope quota slot uniqueness to each goal/tracker.

Revision ID: 024_quota_slot_parent_scope
Revises: 023_quota_check_in_slots
Create Date: 2026-07-13

The initial quota slot index only covered (period_start_at, slot_index), so two
goals or trackers sharing the same quota period start collided on insert.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "024_quota_slot_parent_scope"
down_revision: str | None = "023_quota_check_in_slots"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _rebuild_quota_slot_index(table: str, parent_column: str) -> None:
    op.drop_index(f"ix_{table}_quota_slot", table_name=table)
    op.create_index(
        f"ix_{table}_quota_slot",
        table,
        [parent_column, "period_start_at", "slot_index"],
        unique=True,
        postgresql_where=sa.text("period_start_at IS NOT NULL"),
        sqlite_where=sa.text("period_start_at IS NOT NULL"),
    )


def upgrade() -> None:
    _rebuild_quota_slot_index("goal_check_ins", "goal_id")
    _rebuild_quota_slot_index("tracker_check_ins", "tracker_id")


def downgrade() -> None:
    for table in ("tracker_check_ins", "goal_check_ins"):
        op.drop_index(f"ix_{table}_quota_slot", table_name=table)
        op.create_index(
            f"ix_{table}_quota_slot",
            table,
            ["period_start_at", "slot_index"],
            unique=True,
            postgresql_where=sa.text("period_start_at IS NOT NULL"),
            sqlite_where=sa.text("period_start_at IS NOT NULL"),
        )
