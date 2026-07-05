"""task planned and schedule start/end dates

Revision ID: 011
Revises: 010
Create Date: 2026-06-04

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "011"
down_revision: Union[str, None] = "010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("planned_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        "ck_tasks_planned_before_deadline",
        "tasks",
        "planned_at IS NULL OR deadline IS NULL OR planned_at <= deadline",
    )

    op.add_column(
        "schedules",
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "schedules",
        sa.Column("end_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        "ck_schedules_date_range",
        "schedules",
        "end_date IS NULL OR start_date IS NULL OR end_date > start_date",
    )


def downgrade() -> None:
    op.drop_constraint("ck_schedules_date_range", "schedules", type_="check")
    op.drop_column("schedules", "end_date")
    op.drop_column("schedules", "start_date")

    op.drop_constraint("ck_tasks_planned_before_deadline", "tasks", type_="check")
    op.drop_column("tasks", "planned_at")
