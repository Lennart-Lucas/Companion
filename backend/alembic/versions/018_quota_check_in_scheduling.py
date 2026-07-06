"""Quota check-in scheduling for trackers and goals.

Revision ID: 018_quota_check_in
Revises: 017_tracker_timer_started
Create Date: 2026-07-06
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "018_quota_check_in"
down_revision: str | None = "017_tracker_timer_started"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trackers",
        sa.Column(
            "check_in_mode",
            sa.String(length=32),
            nullable=False,
            server_default="fixed_schedule",
        ),
    )
    op.add_column("trackers", sa.Column("quota_times", sa.Integer(), nullable=True))
    op.add_column(
        "trackers", sa.Column("quota_period_interval", sa.Integer(), nullable=True)
    )
    op.add_column(
        "trackers",
        sa.Column("quota_period_unit", sa.String(length=16), nullable=True),
    )

    op.add_column(
        "goals",
        sa.Column(
            "check_in_mode",
            sa.String(length=32),
            nullable=False,
            server_default="fixed_schedule",
        ),
    )
    op.add_column("goals", sa.Column("quota_times", sa.Integer(), nullable=True))
    op.add_column(
        "goals", sa.Column("quota_period_interval", sa.Integer(), nullable=True)
    )
    op.add_column(
        "goals",
        sa.Column("quota_period_unit", sa.String(length=16), nullable=True),
    )

    op.add_column(
        "tracker_check_ins",
        sa.Column(
            "spawned_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "tracker_check_ins",
        sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "tracker_check_ins",
        sa.Column(
            "slot_kind",
            sa.String(length=16),
            nullable=True,
        ),
    )

    op.add_column(
        "goal_check_ins",
        sa.Column(
            "spawned_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "goal_check_ins",
        sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "goal_check_ins",
        sa.Column(
            "slot_kind",
            sa.String(length=16),
            nullable=True,
        ),
    )

    # Backfill tracker check-ins
    op.execute(
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

    # Backfill goal check-ins
    op.execute(
        """
        UPDATE goal_check_ins
        SET spawned_at = check_in_at,
            slot_kind = CASE
                WHEN completed IS NOT NULL OR count_value IS NOT NULL
                THEN 'locked'
                ELSE 'active'
            END,
            locked_at = CASE
                WHEN completed IS NOT NULL OR count_value IS NOT NULL
                THEN check_in_at
                ELSE NULL
            END
        """
    )

    op.alter_column("tracker_check_ins", "spawned_at", nullable=False)
    op.alter_column("tracker_check_ins", "slot_kind", nullable=False)
    op.alter_column("goal_check_ins", "spawned_at", nullable=False)
    op.alter_column("goal_check_ins", "slot_kind", nullable=False)

    op.alter_column(
        "tracker_check_ins",
        "slot_kind",
        server_default="active",
    )
    op.alter_column(
        "goal_check_ins",
        "slot_kind",
        server_default="active",
    )


def downgrade() -> None:
    op.drop_column("goal_check_ins", "slot_kind")
    op.drop_column("goal_check_ins", "locked_at")
    op.drop_column("goal_check_ins", "spawned_at")

    op.drop_column("tracker_check_ins", "slot_kind")
    op.drop_column("tracker_check_ins", "locked_at")
    op.drop_column("tracker_check_ins", "spawned_at")

    op.drop_column("goals", "quota_period_unit")
    op.drop_column("goals", "quota_period_interval")
    op.drop_column("goals", "quota_times")
    op.drop_column("goals", "check_in_mode")

    op.drop_column("trackers", "quota_period_unit")
    op.drop_column("trackers", "quota_period_interval")
    op.drop_column("trackers", "quota_times")
    op.drop_column("trackers", "check_in_mode")
