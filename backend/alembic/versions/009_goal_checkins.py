"""goal_checkins

Revision ID: 009
Revises: 008
Create Date: 2026-05-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "009"
down_revision: Union[str, None] = "008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "goals",
        sa.Column("schedule_id", sa.Integer(), nullable=False),
    )
    op.add_column(
        "goals",
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=False),
    )
    op.add_column(
        "goals",
        sa.Column("end_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "goals",
        sa.Column("goal_type", sa.String(length=32), nullable=False),
    )
    op.add_column(
        "goals",
        sa.Column("target", sa.Numeric(), nullable=False),
    )
    op.add_column(
        "goals",
        sa.Column("unit", sa.String(length=64), nullable=False),
    )
    op.add_column(
        "goals",
        sa.Column("direction", sa.String(length=16), nullable=False),
    )

    op.create_index(op.f("ix_goals_schedule_id"), "goals", ["schedule_id"], unique=False)
    op.create_foreign_key(
        "fk_goals_schedule_id",
        "goals",
        "schedules",
        ["schedule_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_check_constraint(
        "ck_goals_date_range",
        "goals",
        "end_date IS NULL OR end_date > start_date",
    )

    op.create_table(
        "goal_milestones",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("goal_id", sa.Integer(), nullable=False),
        sa.Column("value", sa.Numeric(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=True),
        sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
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
        sa.ForeignKeyConstraint(["goal_id"], ["goals.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_goal_milestones_goal_id"),
        "goal_milestones",
        ["goal_id"],
        unique=False,
    )

    op.create_table(
        "goal_check_ins",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("goal_id", sa.Integer(), nullable=False),
        sa.Column("check_in_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=True),
        sa.Column("count_value", sa.Numeric(), nullable=True),
        sa.Column("pulse_score", sa.Integer(), nullable=True),
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
        sa.ForeignKeyConstraint(["goal_id"], ["goals.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("goal_id", "check_in_at", name="uq_goal_check_in_at"),
    )
    op.create_index(
        op.f("ix_goal_check_ins_goal_id"),
        "goal_check_ins",
        ["goal_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_goal_check_ins_goal_id"), table_name="goal_check_ins")
    op.drop_table("goal_check_ins")
    op.drop_index(op.f("ix_goal_milestones_goal_id"), table_name="goal_milestones")
    op.drop_table("goal_milestones")
    op.drop_constraint("ck_goals_date_range", "goals", type_="check")
    op.drop_constraint("fk_goals_schedule_id", "goals", type_="foreignkey")
    op.drop_index(op.f("ix_goals_schedule_id"), table_name="goals")
    op.drop_column("goals", "direction")
    op.drop_column("goals", "unit")
    op.drop_column("goals", "target")
    op.drop_column("goals", "goal_type")
    op.drop_column("goals", "end_date")
    op.drop_column("goals", "start_date")
    op.drop_column("goals", "schedule_id")
