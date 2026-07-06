import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.check_in_scheduling import CheckInMode


class CheckInType(str, enum.Enum):
    task = "task"
    count = "count"
    duration = "duration"


class HabitDirection(str, enum.Enum):
    build = "build"
    quit = "quit"


class Tracker(Base):
    __tablename__ = "trackers"
    __table_args__ = (
        CheckConstraint(
            "end_date IS NULL OR end_date > start_date",
            name="ck_trackers_date_range",
        ),
        CheckConstraint(
            "(check_in_type = 'task' AND target IS NULL AND unit IS NULL) OR "
            "(check_in_type = 'count' AND target IS NOT NULL AND unit IS NOT NULL) OR "
            "(check_in_type = 'duration' AND target IS NOT NULL AND unit IS NULL)",
            name="ck_trackers_type_fields",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    schedule_id: Mapped[int] = mapped_column(
        ForeignKey("schedules.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    goal_id: Mapped[int | None] = mapped_column(
        ForeignKey("goals.id", ondelete="SET NULL"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon: Mapped[str | None] = mapped_column(String(64), nullable=True)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
    start_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    end_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    check_in_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target: Mapped[Decimal | None] = mapped_column(Numeric(), nullable=True)
    unit: Mapped[str | None] = mapped_column(String(64), nullable=True)
    habit_direction: Mapped[str] = mapped_column(String(16), nullable=False)
    check_in_mode: Mapped[str] = mapped_column(
        String(32), nullable=False, default=CheckInMode.fixed_schedule.value
    )
    quota_times: Mapped[int | None] = mapped_column(Integer, nullable=True)
    quota_period_interval: Mapped[int | None] = mapped_column(Integer, nullable=True)
    quota_period_unit: Mapped[str | None] = mapped_column(String(16), nullable=True)
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

    user: Mapped["User"] = relationship(back_populates="trackers")
    goal: Mapped["Goal | None"] = relationship(back_populates="trackers")
    schedule: Mapped["Schedule"] = relationship(back_populates="trackers")
    check_ins: Mapped[list["TrackerCheckIn"]] = relationship(
        back_populates="tracker",
        cascade="all, delete-orphan",
        order_by="TrackerCheckIn.check_in_at",
    )
