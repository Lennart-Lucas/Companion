from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class TaskSubtask(Base):
    __tablename__ = "task_subtasks"
    __table_args__ = (
        UniqueConstraint("task_id", "sort_order", name="uq_task_subtask_sort_order"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    task_id: Mapped[int] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    task: Mapped["Task"] = relationship(back_populates="subtask_templates")
    occurrence_states: Mapped[list["TaskOccurrenceSubtask"]] = relationship(
        back_populates="subtask", cascade="all, delete-orphan"
    )
