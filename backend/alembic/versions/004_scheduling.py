"""scheduling

Revision ID: 004
Revises: 003
Create Date: 2026-05-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "004"
down_revision: Union[str, None] = "003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "schedules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("repeat_type", sa.String(length=32), nullable=False),
        sa.Column("interval", sa.Integer(), nullable=True),
        sa.Column("weekdays", postgresql.ARRAY(sa.Integer()), nullable=True),
        sa.Column("month_days", postgresql.ARRAY(sa.Integer()), nullable=True),
        sa.Column("anchor_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_schedules_user_id"), "schedules", ["user_id"], unique=False)

    op.create_table(
        "schedule_specific_dates",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("schedule_id", sa.Integer(), nullable=False),
        sa.Column("occurrence_date", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["schedule_id"], ["schedules.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "schedule_id", "occurrence_date", name="uq_schedule_specific_date"
        ),
    )
    op.create_index(
        op.f("ix_schedule_specific_dates_schedule_id"),
        "schedule_specific_dates",
        ["schedule_id"],
        unique=False,
    )

    op.create_table(
        "schedule_exclusions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("schedule_id", sa.Integer(), nullable=False),
        sa.Column("excluded_date", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["schedule_id"], ["schedules.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "schedule_id", "excluded_date", name="uq_schedule_exclusion"
        ),
    )
    op.create_index(
        op.f("ix_schedule_exclusions_schedule_id"),
        "schedule_exclusions",
        ["schedule_id"],
        unique=False,
    )

    op.create_table(
        "schedule_overrides",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("schedule_id", sa.Integer(), nullable=False),
        sa.Column("scope", sa.String(length=32), nullable=False),
        sa.Column("effective_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("replacement_schedule_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["schedule_id"], ["schedules.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["replacement_schedule_id"], ["schedules.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_schedule_overrides_schedule_id"),
        "schedule_overrides",
        ["schedule_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_schedule_overrides_replacement_schedule_id"),
        "schedule_overrides",
        ["replacement_schedule_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_schedule_overrides_replacement_schedule_id"),
        table_name="schedule_overrides",
    )
    op.drop_index(
        op.f("ix_schedule_overrides_schedule_id"), table_name="schedule_overrides"
    )
    op.drop_table("schedule_overrides")
    op.drop_index(
        op.f("ix_schedule_exclusions_schedule_id"), table_name="schedule_exclusions"
    )
    op.drop_table("schedule_exclusions")
    op.drop_index(
        op.f("ix_schedule_specific_dates_schedule_id"),
        table_name="schedule_specific_dates",
    )
    op.drop_table("schedule_specific_dates")
    op.drop_index(op.f("ix_schedules_user_id"), table_name="schedules")
    op.drop_table("schedules")
