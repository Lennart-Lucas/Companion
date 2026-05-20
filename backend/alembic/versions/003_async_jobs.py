"""async_jobs

Revision ID: 003
Revises: 002
Create Date: 2026-05-20

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "async_jobs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("task_name", sa.String(length=128), nullable=False),
        sa.Column("parameters", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("retry_count", sa.Integer(), nullable=False),
        sa.Column("max_retries", sa.Integer(), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("locked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("locked_by", sa.String(length=64), nullable=True),
        sa.Column("last_error", sa.String(length=512), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_async_jobs_task_name"), "async_jobs", ["task_name"], unique=False
    )
    op.create_index(
        "ix_async_jobs_status_scheduled_at",
        "async_jobs",
        ["status", "scheduled_at"],
        unique=False,
    )
    op.create_index(
        "ix_async_jobs_status_completed_at",
        "async_jobs",
        ["status", "completed_at"],
        unique=False,
    )
    op.create_table(
        "async_job_errors",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("job_id", sa.Integer(), nullable=False),
        sa.Column("attempt", sa.Integer(), nullable=False),
        sa.Column("message", sa.String(length=512), nullable=False),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["job_id"], ["async_jobs.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_async_job_errors_job_id"), "async_job_errors", ["job_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_async_job_errors_job_id"), table_name="async_job_errors")
    op.drop_table("async_job_errors")
    op.drop_index("ix_async_jobs_status_completed_at", table_name="async_jobs")
    op.drop_index("ix_async_jobs_status_scheduled_at", table_name="async_jobs")
    op.drop_index(op.f("ix_async_jobs_task_name"), table_name="async_jobs")
    op.drop_table("async_jobs")
