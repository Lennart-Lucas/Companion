"""Ensure goal milestone schema exists (repair prod drift).

Revision ID: 018_goal_schema_repair
Revises: 017_tracker_timer_started
Create Date: 2026-07-09

Some production databases were stamped at productivity-only revisions (e.g.
018_quota_check_in) without matching files on main, or missed goal tables while
Alembic advanced. This migration idempotently creates goal_milestones when
absent so goal create/list can load milestones.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "018_goal_schema_repair"
down_revision: str | None = "017_tracker_timer_started"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = set(inspector.get_table_names())

    if "goal_milestones" in tables:
        return

    if "goals" not in tables:
        raise RuntimeError(
            "goals table is missing; run earlier migrations before "
            "018_goal_schema_repair"
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


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "goal_milestones" not in inspector.get_table_names():
        return
    op.drop_index(op.f("ix_goal_milestones_goal_id"), table_name="goal_milestones")
    op.drop_table("goal_milestones")
