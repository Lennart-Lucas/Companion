from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AsyncJobError(Base):
    __tablename__ = "async_job_errors"

    id: Mapped[int] = mapped_column(primary_key=True)
    job_id: Mapped[int] = mapped_column(
        ForeignKey("async_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    attempt: Mapped[int] = mapped_column(Integer, nullable=False)
    message: Mapped[str] = mapped_column(String(512), nullable=False)
    detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    job: Mapped["AsyncJob"] = relationship(back_populates="errors")
