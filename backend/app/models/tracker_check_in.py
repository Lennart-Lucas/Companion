from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class TrackerCheckIn(Base):
    __tablename__ = "tracker_check_ins"
    __table_args__ = (
        UniqueConstraint("tracker_id", "check_in_at", name="uq_tracker_check_in_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    tracker_id: Mapped[int] = mapped_column(
        ForeignKey("trackers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    check_in_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    completed: Mapped[bool | None] = mapped_column(nullable=True)
    count_value: Mapped[Decimal | None] = mapped_column(Numeric(), nullable=True)
    value_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    timer_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    skipped: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    spawned_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    locked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    slot_kind: Mapped[str | None] = mapped_column(String(16), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    tracker: Mapped["Tracker"] = relationship(back_populates="check_ins")
