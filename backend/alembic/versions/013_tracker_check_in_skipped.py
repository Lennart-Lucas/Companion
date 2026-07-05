"""Add skipped flag to tracker check-ins.

Revision ID: 013_tracker_check_in_skipped
Revises: 012
Create Date: 2026-06-30
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "013_tracker_check_in_skipped"
down_revision: str | None = "012_soft_delete_sync"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tracker_check_ins",
        sa.Column(
            "skipped",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("tracker_check_ins", "skipped")
