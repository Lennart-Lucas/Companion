"""Add watch tracking fields and media_watch_entries table.

Revision ID: 021_media_watch_tracking
Revises: 020_media_titles
Create Date: 2026-07-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "021_media_watch_tracking"
down_revision: str | None = "020_media_titles"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "media_titles",
        sa.Column(
            "watch_status",
            sa.String(length=32),
            nullable=False,
            server_default="plan_to_watch",
        ),
    )
    op.add_column(
        "media_titles",
        sa.Column("user_rating", sa.Numeric(precision=2, scale=1), nullable=True),
    )
    op.add_column(
        "media_titles",
        sa.Column("notes", sa.Text(), nullable=True),
    )

    op.create_table(
        "media_watch_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("media_title_id", sa.Integer(), nullable=False),
        sa.Column("season_number", sa.Integer(), nullable=True),
        sa.Column("episode_number", sa.Integer(), nullable=True),
        sa.Column("episode_imdb_id", sa.String(length=16), nullable=True),
        sa.Column("episode_title", sa.String(length=255), nullable=True),
        sa.Column("watched_at", sa.DateTime(timezone=True), nullable=False),
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
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["media_title_id"], ["media_titles.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_media_watch_entries_media_title_id"),
        "media_watch_entries",
        ["media_title_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_media_watch_entries_deleted_at"),
        "media_watch_entries",
        ["deleted_at"],
        unique=False,
    )
    op.create_index(
        "uq_media_watch_entries_title_episode",
        "media_watch_entries",
        [
            "media_title_id",
            sa.text("COALESCE(season_number, -1)"),
            sa.text("COALESCE(episode_number, -1)"),
        ],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_media_watch_entries_title_episode",
        table_name="media_watch_entries",
    )
    op.drop_index(
        op.f("ix_media_watch_entries_deleted_at"), table_name="media_watch_entries"
    )
    op.drop_index(
        op.f("ix_media_watch_entries_media_title_id"), table_name="media_watch_entries"
    )
    op.drop_table("media_watch_entries")
    op.drop_column("media_titles", "notes")
    op.drop_column("media_titles", "user_rating")
    op.drop_column("media_titles", "watch_status")
