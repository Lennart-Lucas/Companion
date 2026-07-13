"""Add quota schedule fields.

Revision ID: 022_quota_schedule_fields
Revises: 021_media_watch_tracking
Create Date: 2026-07-13
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "022_quota_schedule_fields"
down_revision: str | None = "021_media_watch_tracking"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "schedules",
        sa.Column("quota_times", sa.Integer(), nullable=True),
    )
    op.add_column(
        "schedules",
        sa.Column("quota_period_weeks", sa.Integer(), nullable=True),
    )
    op.create_check_constraint(
        "ck_schedules_quota_fields",
        "schedules",
        "(quota_times IS NULL AND quota_period_weeks IS NULL) OR "
        "(quota_times IS NOT NULL AND quota_period_weeks IS NOT NULL "
        "AND quota_times >= 1 AND quota_period_weeks >= 1)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_schedules_quota_fields", "schedules", type_="check")
    op.drop_column("schedules", "quota_period_weeks")
    op.drop_column("schedules", "quota_times")
