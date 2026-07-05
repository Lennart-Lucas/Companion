"""task_expansion

Revision ID: 006
Revises: 005
Create Date: 2026-05-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("schedule_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "tasks",
        sa.Column(
            "status",
            sa.String(length=32),
            server_default="pending",
            nullable=False,
        ),
    )
    op.add_column(
        "tasks",
        sa.Column(
            "priority",
            sa.String(length=32),
            server_default="medium",
            nullable=False,
        ),
    )
    op.create_index(op.f("ix_tasks_schedule_id"), "tasks", ["schedule_id"], unique=False)
    op.create_foreign_key(
        "fk_tasks_schedule_id",
        "tasks",
        "schedules",
        ["schedule_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "task_subtasks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("task_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "task_id", "sort_order", name="uq_task_subtask_sort_order"
        ),
    )
    op.create_index(
        op.f("ix_task_subtasks_task_id"), "task_subtasks", ["task_id"], unique=False
    )

    op.create_table(
        "task_occurrences",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("task_id", sa.Integer(), nullable=False),
        sa.Column("occurrence_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "status",
            sa.String(length=32),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "priority",
            sa.String(length=32),
            server_default="medium",
            nullable=False,
        ),
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
        sa.ForeignKeyConstraint(["task_id"], ["tasks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("task_id", "occurrence_at", name="uq_task_occurrence_at"),
    )
    op.create_index(
        op.f("ix_task_occurrences_task_id"),
        "task_occurrences",
        ["task_id"],
        unique=False,
    )

    op.create_table(
        "task_occurrence_subtasks",
        sa.Column("occurrence_id", sa.Integer(), nullable=False),
        sa.Column("subtask_id", sa.Integer(), nullable=False),
        sa.Column("completed", sa.Boolean(), server_default="false", nullable=False),
        sa.ForeignKeyConstraint(
            ["occurrence_id"], ["task_occurrences.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["subtask_id"], ["task_subtasks.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("occurrence_id", "subtask_id"),
    )


def downgrade() -> None:
    op.drop_table("task_occurrence_subtasks")
    op.drop_index(op.f("ix_task_occurrences_task_id"), table_name="task_occurrences")
    op.drop_table("task_occurrences")
    op.drop_index(op.f("ix_task_subtasks_task_id"), table_name="task_subtasks")
    op.drop_table("task_subtasks")
    op.drop_constraint("fk_tasks_schedule_id", "tasks", type_="foreignkey")
    op.drop_index(op.f("ix_tasks_schedule_id"), table_name="tasks")
    op.drop_column("tasks", "priority")
    op.drop_column("tasks", "status")
    op.drop_column("tasks", "schedule_id")
