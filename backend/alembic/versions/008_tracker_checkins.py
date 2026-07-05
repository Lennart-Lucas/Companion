"""tracker_checkins

Revision ID: 008
Revises: 007
Create Date: 2026-05-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "008"
down_revision: Union[str, None] = "007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trackers",
        sa.Column("schedule_id", sa.Integer(), nullable=False),
    )
    op.add_column(
        "trackers",
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
    )
    op.add_column(
        "trackers",
        sa.Column("end_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "trackers",
        sa.Column("check_in_type", sa.String(length=32), nullable=False),
    )
    op.add_column(
        "trackers",
        sa.Column("target", sa.Numeric(), nullable=True),
    )
    op.add_column(
        "trackers",
        sa.Column("unit", sa.String(length=64), nullable=True),
    )
    op.add_column(
        "trackers",
        sa.Column("habit_direction", sa.String(length=16), nullable=False),
    )

    op.create_index(
        op.f("ix_trackers_schedule_id"), "trackers", ["schedule_id"], unique=False
    )
    op.create_foreign_key(
        "fk_trackers_schedule_id",
        "trackers",
        "schedules",
        ["schedule_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    op.create_check_constraint(
        "ck_trackers_date_range",
        "trackers",
        "end_date IS NULL OR end_date > start_date",
    )
    op.create_check_constraint(
        "ck_trackers_type_fields",
        "trackers",
        "(check_in_type = 'task' AND target IS NULL AND unit IS NULL) OR "
        "(check_in_type = 'count' AND target IS NOT NULL AND unit IS NOT NULL) OR "
        "(check_in_type = 'duration' AND target IS NOT NULL AND unit IS NULL)",
    )

    op.create_table(
        "tracker_check_ins",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("tracker_id", sa.Integer(), nullable=False),
        sa.Column("check_in_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=True),
        sa.Column("count_value", sa.Numeric(), nullable=True),
        sa.Column("value_seconds", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["tracker_id"], ["trackers.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "tracker_id", "check_in_at", name="uq_tracker_check_in_at"
        ),
    )
    op.create_index(
        op.f("ix_tracker_check_ins_tracker_id"),
        "tracker_check_ins",
        ["tracker_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_tracker_check_ins_tracker_id"), table_name="tracker_check_ins"
    )
    op.drop_table("tracker_check_ins")
    op.drop_constraint("ck_trackers_type_fields", "trackers", type_="check")
    op.drop_constraint("ck_trackers_date_range", "trackers", type_="check")
    op.drop_constraint("fk_trackers_schedule_id", "trackers", type_="foreignkey")
    op.drop_index(op.f("ix_trackers_schedule_id"), table_name="trackers")
    op.drop_column("trackers", "habit_direction")
    op.drop_column("trackers", "unit")
    op.drop_column("trackers", "target")
    op.drop_column("trackers", "check_in_type")
    op.drop_column("trackers", "end_date")
    op.drop_column("trackers", "start_date")
    op.drop_column("trackers", "schedule_id")
