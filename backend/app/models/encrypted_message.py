from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EncryptedMessage(Base):
    __tablename__ = "encrypted_messages"
    __table_args__ = (
        Index(
            "ix_encrypted_messages_recipient_undelivered",
            "recipient_user_id",
            postgresql_where=text("delivered_at IS NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    sender_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sender_device_id: Mapped[int] = mapped_column(Integer, nullable=False)
    recipient_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    recipient_device_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ciphertext: Mapped[str] = mapped_column(Text, nullable=False)
    envelope_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    message_type: Mapped[str] = mapped_column(String(32), nullable=False)
    delivered_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
