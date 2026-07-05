from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class ScheduleSpecificDate(Base):
    __tablename__ = "schedule_specific_dates"
    __table_args__ = (
        UniqueConstraint(
            "schedule_id", "occurrence_date", name="uq_schedule_specific_date"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    schedule_id: Mapped[int] = mapped_column(
        ForeignKey("schedules.id", ondelete="CASCADE"), nullable=False, index=True
    )
    occurrence_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    schedule: Mapped["Schedule"] = relationship(back_populates="specific_dates")
