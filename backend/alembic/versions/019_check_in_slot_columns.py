"""Add check-in slot columns for materialized check-ins (prod 018 compat).

Revision ID: 019_check_in_slot_columns
Revises: 018_goal_schema_repair
Create Date: 2026-07-09

Production databases migrated from the old productivity branch already have
spawned_at / locked_at / slot_kind on goal_check_ins and tracker_check_ins.
This migration adds them on fresh databases that never ran 018_quota_check_in.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "019_check_in_slot_columns"
down_revision: str | None = "018_goal_schema_repair"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _column_names(inspector, table: str) -> set[str]:
    return {column["name"] for column in inspector.get_columns(table)}


def _upgrade_goal_check_ins() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    table = "goal_check_ins"
    if table not in inspector.get_table_names():
        return
    if "spawned_at" in _column_names(inspector, table):
        return

    op.add_column(
        table, sa.Column("spawned_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(
        table, sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(table, sa.Column("slot_kind", sa.String(length=16), nullable=True))

    op.execute(
        sa.text(
            """
            UPDATE goal_check_ins
            SET spawned_at = check_in_at,
                slot_kind = CASE
                    WHEN completed IS NOT NULL
                        OR count_value IS NOT NULL
                        OR pulse_score IS NOT NULL
                    THEN 'locked'
                    ELSE 'active'
                END,
                locked_at = CASE
                    WHEN completed IS NOT NULL
                        OR count_value IS NOT NULL
                        OR pulse_score IS NOT NULL
                    THEN check_in_at
                    ELSE NULL
                END
            """
        )
    )
    op.alter_column(table, "spawned_at", nullable=False)
    op.alter_column(table, "slot_kind", nullable=False, server_default="active")


def _upgrade_tracker_check_ins() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    table = "tracker_check_ins"
    if table not in inspector.get_table_names():
        return
    if "spawned_at" in _column_names(inspector, table):
        return

    op.add_column(
        table, sa.Column("spawned_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(
        table, sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.add_column(table, sa.Column("slot_kind", sa.String(length=16), nullable=True))

    op.execute(
        sa.text(
            """
            UPDATE tracker_check_ins
            SET spawned_at = check_in_at,
                slot_kind = CASE
                    WHEN skipped = TRUE
                        OR completed IS NOT NULL
                        OR count_value IS NOT NULL
                        OR value_seconds IS NOT NULL
                    THEN 'locked'
                    ELSE 'active'
                END,
                locked_at = CASE
                    WHEN skipped = TRUE
                        OR completed IS NOT NULL
                        OR count_value IS NOT NULL
                        OR value_seconds IS NOT NULL
                    THEN check_in_at
                    ELSE NULL
                END
            """
        )
    )
    op.alter_column(table, "spawned_at", nullable=False)
    op.alter_column(table, "slot_kind", nullable=False, server_default="active")


def upgrade() -> None:
    _upgrade_goal_check_ins()
    _upgrade_tracker_check_ins()


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    for table in ("goal_check_ins", "tracker_check_ins"):
        if table not in inspector.get_table_names():
            continue
        columns = _column_names(inspector, table)
        if "slot_kind" in columns:
            op.drop_column(table, "slot_kind")
        if "locked_at" in columns:
            op.drop_column(table, "locked_at")
        if "spawned_at" in columns:
            op.drop_column(table, "spawned_at")
