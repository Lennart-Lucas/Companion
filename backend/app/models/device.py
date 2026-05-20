from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Device(Base):
    __tablename__ = "devices"
    __table_args__ = (UniqueConstraint("user_id", "device_id", name="uq_user_device"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    device_id: Mapped[int] = mapped_column(Integer, nullable=False)
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)
    registration_id: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="devices")
    identity_key: Mapped["IdentityKey | None"] = relationship(
        back_populates="device", cascade="all, delete-orphan", uselist=False
    )
    signed_prekeys: Mapped[list["SignedPreKey"]] = relationship(
        back_populates="device", cascade="all, delete-orphan"
    )
    one_time_prekeys: Mapped[list["OneTimePreKey"]] = relationship(
        back_populates="device", cascade="all, delete-orphan"
    )
