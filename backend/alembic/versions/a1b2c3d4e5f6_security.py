"""security: auth and e2e tables

Revision ID: a1b2c3d4e5f6
Revises: df17ee0f5ff6
Create Date: 2026-05-20 12:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "df17ee0f5ff6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
    )
    op.add_column(
        "users",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.execute(
        "UPDATE users SET password_hash = '' WHERE password_hash IS NULL"
    )
    op.alter_column("users", "password_hash", nullable=False)
    op.alter_column("users", "is_active", server_default=None)

    op.create_table(
        "refresh_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index(
        op.f("ix_refresh_tokens_user_id"), "refresh_tokens", ["user_id"], unique=False
    )

    op.create_table(
        "devices",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(length=128), nullable=True),
        sa.Column("registration_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "device_id", name="uq_user_device"),
    )
    op.create_index(op.f("ix_devices_user_id"), "devices", ["user_id"], unique=False)

    op.create_table(
        "identity_keys",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.Integer(), nullable=False),
        sa.Column("public_key", sa.String(length=2048), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("device_id"),
    )

    op.create_table(
        "signed_prekeys",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.Integer(), nullable=False),
        sa.Column("key_id", sa.Integer(), nullable=False),
        sa.Column("public_key", sa.String(length=2048), nullable=False),
        sa.Column("signature", sa.String(length=2048), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_signed_prekeys_device_id"),
        "signed_prekeys",
        ["device_id"],
        unique=False,
    )

    op.create_table(
        "one_time_prekeys",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.Integer(), nullable=False),
        sa.Column("key_id", sa.Integer(), nullable=False),
        sa.Column("public_key", sa.String(length=2048), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_one_time_prekeys_device_id"),
        "one_time_prekeys",
        ["device_id"],
        unique=False,
    )

    op.create_table(
        "encrypted_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("sender_user_id", sa.Integer(), nullable=False),
        sa.Column("sender_device_id", sa.Integer(), nullable=False),
        sa.Column("recipient_user_id", sa.Integer(), nullable=False),
        sa.Column("recipient_device_id", sa.Integer(), nullable=True),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("envelope_version", sa.Integer(), nullable=False),
        sa.Column("message_type", sa.String(length=32), nullable=False),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["recipient_user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["sender_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_encrypted_messages_recipient_user_id"),
        "encrypted_messages",
        ["recipient_user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_encrypted_messages_sender_user_id"),
        "encrypted_messages",
        ["sender_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_encrypted_messages_recipient_undelivered",
        "encrypted_messages",
        ["recipient_user_id"],
        unique=False,
        postgresql_where=sa.text("delivered_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "ix_encrypted_messages_recipient_undelivered", table_name="encrypted_messages"
    )
    op.drop_index(
        op.f("ix_encrypted_messages_sender_user_id"), table_name="encrypted_messages"
    )
    op.drop_index(
        op.f("ix_encrypted_messages_recipient_user_id"),
        table_name="encrypted_messages",
    )
    op.drop_table("encrypted_messages")
    op.drop_index(
        op.f("ix_one_time_prekeys_device_id"), table_name="one_time_prekeys"
    )
    op.drop_table("one_time_prekeys")
    op.drop_index(op.f("ix_signed_prekeys_device_id"), table_name="signed_prekeys")
    op.drop_table("signed_prekeys")
    op.drop_table("identity_keys")
    op.drop_index(op.f("ix_devices_user_id"), table_name="devices")
    op.drop_table("devices")
    op.drop_index(op.f("ix_refresh_tokens_user_id"), table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
    op.drop_column("users", "updated_at")
    op.drop_column("users", "created_at")
    op.drop_column("users", "is_active")
    op.drop_column("users", "password_hash")
