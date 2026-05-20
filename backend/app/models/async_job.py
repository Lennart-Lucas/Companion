import enum
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class JobStatus(str, enum.Enum):
    pending = "pending"
    running = "running"
    completed = "completed"
    failed = "failed"


class AsyncJob(Base):
    __tablename__ = "async_jobs"
    __table_args__ = (
        Index("ix_async_jobs_status_scheduled_at", "status", "scheduled_at"),
        Index("ix_async_jobs_status_completed_at", "status", "completed_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    task_name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    parameters: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=JobStatus.pending.value
    )
    retry_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_retries: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    scheduled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    locked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    locked_by: Mapped[str | None] = mapped_column(String(64), nullable=True)
    last_error: Mapped[str | None] = mapped_column(String(512), nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    errors: Mapped[list["AsyncJobError"]] = relationship(
        back_populates="job", cascade="all, delete-orphan"
    )
