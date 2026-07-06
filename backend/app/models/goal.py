import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.check_in_scheduling import CheckInMode


class GoalType(str, enum.Enum):
    count = "count"
    task = "task"
    pulse = "pulse"


class GoalDirection(str, enum.Enum):
    increasing = "increasing"
    decreasing = "decreasing"


class Goal(Base):
    __tablename__ = "goals"
    __table_args__ = (
        CheckConstraint(
            "end_date IS NULL OR end_date > start_date",
            name="ck_goals_date_range",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    schedule_id: Mapped[int] = mapped_column(
        ForeignKey("schedules.id", ondelete="RESTRICT"), nullable=False, index=True
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
    goal_type: Mapped[str] = mapped_column(String(32), nullable=False)
    target: Mapped[Decimal] = mapped_column(Numeric(), nullable=False)
    unit: Mapped[str] = mapped_column(String(64), nullable=False)
    direction: Mapped[str] = mapped_column(String(16), nullable=False)
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

    user: Mapped["User"] = relationship(back_populates="goals")
    schedule: Mapped["Schedule"] = relationship(back_populates="goals")
    milestones: Mapped[list["GoalMilestone"]] = relationship(
        back_populates="goal",
        cascade="all, delete-orphan",
        order_by="GoalMilestone.sort_order",
    )
    check_ins: Mapped[list["GoalCheckIn"]] = relationship(
        back_populates="goal",
        cascade="all, delete-orphan",
        order_by="GoalCheckIn.check_in_at",
    )
    projects: Mapped[list["Project"]] = relationship(back_populates="goal")
    tasks: Mapped[list["Task"]] = relationship(back_populates="goal")
    trackers: Mapped[list["Tracker"]] = relationship(back_populates="goal")
