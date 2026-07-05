"""Add timer_started_at to tracker check-ins.

Revision ID: 017_tracker_timer_started
Revises: 016_rrule_schedules
Create Date: 2026-07-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "017_tracker_timer_started"
down_revision: str | None = "016_rrule_schedules"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tracker_check_ins",
        sa.Column("timer_started_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tracker_check_ins", "timer_started_at")
