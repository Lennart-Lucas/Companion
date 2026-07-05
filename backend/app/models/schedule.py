from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Schedule(Base):
    __tablename__ = "schedules"
    __table_args__ = (
        CheckConstraint(
            "end_date IS NULL OR start_date IS NULL OR end_date > start_date",
            name="ck_schedules_date_range",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    dtstart: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    rrule: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    end_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    timezone: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )

    user: Mapped["User"] = relationship(back_populates="schedules")
    specific_dates: Mapped[list["ScheduleSpecificDate"]] = relationship(
        back_populates="schedule", cascade="all, delete-orphan"
    )
    exclusions: Mapped[list["ScheduleExclusion"]] = relationship(
        back_populates="schedule", cascade="all, delete-orphan"
    )
    overrides: Mapped[list["ScheduleOverride"]] = relationship(
        back_populates="schedule",
        cascade="all, delete-orphan",
        foreign_keys="ScheduleOverride.schedule_id",
    )
    tasks: Mapped[list["Task"]] = relationship(back_populates="schedule")
    trackers: Mapped[list["Tracker"]] = relationship(back_populates="schedule")
    goals: Mapped[list["Goal"]] = relationship(back_populates="schedule")
    events: Mapped[list["Event"]] = relationship(back_populates="schedule")
