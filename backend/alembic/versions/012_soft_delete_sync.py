"""Add soft deletes and subtask timestamps for offline sync.

Revision ID: 012_soft_delete_sync
Revises: 011
Create Date: 2026-06-07
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "012_soft_delete_sync"
down_revision: Union[str, None] = "011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_SOFT_DELETE_TABLES = ("goals", "trackers", "projects", "tasks", "schedules")


def upgrade() -> None:
    for table in _SOFT_DELETE_TABLES:
        op.add_column(
            table,
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index(f"ix_{table}_deleted_at", table, ["deleted_at"])

    op.add_column(
        "task_subtasks",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.add_column(
        "task_occurrence_subtasks",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("task_occurrence_subtasks", "updated_at")
    op.drop_column("task_subtasks", "updated_at")
    for table in reversed(_SOFT_DELETE_TABLES):
        op.drop_index(f"ix_{table}_deleted_at", table_name=table)
        op.drop_column(table, "deleted_at")
