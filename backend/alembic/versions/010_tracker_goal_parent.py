"""tracker goal parent

Revision ID: 010
Revises: 009
Create Date: 2026-05-28

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "010"
down_revision: Union[str, None] = "009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("trackers", sa.Column("goal_id", sa.Integer(), nullable=True))
    op.create_index(op.f("ix_trackers_goal_id"), "trackers", ["goal_id"], unique=False)
    op.create_foreign_key(
        "fk_trackers_goal_id_goals",
        "trackers",
        "goals",
        ["goal_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_trackers_goal_id_goals", "trackers", type_="foreignkey")
    op.drop_index(op.f("ix_trackers_goal_id"), table_name="trackers")
    op.drop_column("trackers", "goal_id")
