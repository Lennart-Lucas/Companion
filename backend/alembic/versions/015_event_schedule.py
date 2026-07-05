"""Add schedule_id to events.

Revision ID: 015_event_schedule
Revises: 014_events
Create Date: 2026-07-02
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "015_event_schedule"
down_revision: str | None = "014_events"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("events", sa.Column("schedule_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_events_schedule_id_schedules",
        "events",
        "schedules",
        ["schedule_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        op.f("ix_events_schedule_id"), "events", ["schedule_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_events_schedule_id"), table_name="events")
    op.drop_constraint("fk_events_schedule_id_schedules", "events", type_="foreignkey")
    op.drop_column("events", "schedule_id")
