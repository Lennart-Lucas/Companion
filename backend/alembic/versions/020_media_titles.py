"""Add media_titles table for Movies & TV library.

Revision ID: 020_media_titles
Revises: 019_check_in_slot_columns
Create Date: 2026-07-10
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "020_media_titles"
down_revision: str | None = "019_check_in_slot_columns"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "media_titles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("imdb_id", sa.String(length=16), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("media_type", sa.String(length=32), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("poster_url", sa.String(length=512), nullable=True),
        sa.Column("imdb_url", sa.String(length=255), nullable=False),
        sa.Column("rating", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("vote_count", sa.Integer(), nullable=True),
        sa.Column("genres", sa.JSON(), nullable=True),
        sa.Column("runtime_minutes", sa.Integer(), nullable=True),
        sa.Column("cast", sa.JSON(), nullable=True),
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "imdb_id", name="uq_media_titles_user_imdb"),
    )
    op.create_index(
        op.f("ix_media_titles_user_id"), "media_titles", ["user_id"], unique=False
    )
    op.create_index(
        op.f("ix_media_titles_imdb_id"), "media_titles", ["imdb_id"], unique=False
    )
    op.create_index(
        op.f("ix_media_titles_deleted_at"), "media_titles", ["deleted_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_media_titles_deleted_at"), table_name="media_titles")
    op.drop_index(op.f("ix_media_titles_imdb_id"), table_name="media_titles")
    op.drop_index(op.f("ix_media_titles_user_id"), table_name="media_titles")
    op.drop_table("media_titles")
