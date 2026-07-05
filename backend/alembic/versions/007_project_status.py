"""project_status

Revision ID: 007
Revises: 006
Create Date: 2026-05-21

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "007"
down_revision: Union[str, None] = "006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "projects",
        sa.Column("start_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "projects",
        sa.Column(
            "status",
            sa.String(length=32),
            server_default="planning",
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("projects", "status")
    op.drop_column("projects", "start_date")
