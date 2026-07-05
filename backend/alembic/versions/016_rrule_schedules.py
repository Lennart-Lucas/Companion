"""Replace repeat_type columns with RRULE on schedules.

Revision ID: 016_rrule_schedules
Revises: 015_event_schedule
Create Date: 2026-07-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "016_rrule_schedules"
down_revision: str | None = "015_event_schedule"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("schedules", sa.Column("rrule", sa.Text(), nullable=True))
    op.alter_column("schedules", "anchor_at", new_column_name="dtstart")
    op.drop_column("schedules", "repeat_type")
    op.drop_column("schedules", "interval")
    op.drop_column("schedules", "weekdays")
    op.drop_column("schedules", "month_days")


def downgrade() -> None:
    op.add_column(
        "schedules",
        sa.Column("repeat_type", sa.String(length=32), nullable=False, server_default="none"),
    )
    op.add_column("schedules", sa.Column("interval", sa.Integer(), nullable=True))
    op.add_column(
        "schedules",
        sa.Column("weekdays", sa.ARRAY(sa.Integer()), nullable=True),
    )
    op.add_column(
        "schedules",
        sa.Column("month_days", sa.ARRAY(sa.Integer()), nullable=True),
    )
    op.alter_column("schedules", "dtstart", new_column_name="anchor_at")
    op.drop_column("schedules", "rrule")
    op.alter_column("schedules", "repeat_type", server_default=None)
