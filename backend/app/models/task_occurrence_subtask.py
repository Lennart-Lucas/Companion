from sqlalchemy import Boolean, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class TaskOccurrenceSubtask(Base):
    __tablename__ = "task_occurrence_subtasks"

    occurrence_id: Mapped[int] = mapped_column(
        ForeignKey("task_occurrences.id", ondelete="CASCADE"),
        primary_key=True,
    )
    subtask_id: Mapped[int] = mapped_column(
        ForeignKey("task_subtasks.id", ondelete="CASCADE"),
        primary_key=True,
    )
    completed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    occurrence: Mapped["TaskOccurrence"] = relationship(back_populates="subtask_states")
    subtask: Mapped["TaskSubtask"] = relationship(back_populates="occurrence_states")
