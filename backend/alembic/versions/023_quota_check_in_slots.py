"""Add quota slot identity columns on check-ins.

Revision ID: 023_quota_check_in_slots
Revises: 022_quota_schedule_fields
Create Date: 2026-07-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "023_quota_check_in_slots"
down_revision: str | None = "022_quota_schedule_fields"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _add_quota_columns(table: str) -> None:
    op.add_column(
        table,
        sa.Column("period_start_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(table, sa.Column("slot_index", sa.Integer(), nullable=True))
    op.create_index(
        f"ix_{table}_quota_slot",
        table,
        ["period_start_at", "slot_index"],
        unique=True,
        postgresql_where=sa.text("period_start_at IS NOT NULL"),
        sqlite_where=sa.text("period_start_at IS NOT NULL"),
    )


def _drop_quota_columns(table: str) -> None:
    op.drop_index(f"ix_{table}_quota_slot", table_name=table)
    op.drop_column(table, "slot_index")
    op.drop_column(table, "period_start_at")


def upgrade() -> None:
    _add_quota_columns("goal_check_ins")
    _add_quota_columns("tracker_check_ins")


def downgrade() -> None:
    _drop_quota_columns("tracker_check_ins")
    _drop_quota_columns("goal_check_ins")
