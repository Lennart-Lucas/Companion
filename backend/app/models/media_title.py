from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

WATCH_STATUS_PLAN_TO_WATCH = "plan_to_watch"
WATCH_STATUS_WATCHING = "watching"
WATCH_STATUS_COMPLETED = "completed"
WATCH_STATUS_ON_HOLD = "on_hold"
WATCH_STATUS_DROPPED = "dropped"

WATCH_STATUSES = frozenset(
    {
        WATCH_STATUS_PLAN_TO_WATCH,
        WATCH_STATUS_WATCHING,
        WATCH_STATUS_COMPLETED,
        WATCH_STATUS_ON_HOLD,
        WATCH_STATUS_DROPPED,
    }
)


class MediaTitle(Base):
    __tablename__ = "media_titles"
    __table_args__ = (
        UniqueConstraint("user_id", "imdb_id", name="uq_media_titles_user_imdb"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    imdb_id: Mapped[str] = mapped_column(String(16), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    media_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    poster_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    imdb_url: Mapped[str] = mapped_column(String(255), nullable=False)
    rating: Mapped[float | None] = mapped_column(Numeric(4, 1), nullable=True)
    vote_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    genres: Mapped[list | None] = mapped_column(JSON, nullable=True)
    runtime_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cast: Mapped[list | None] = mapped_column(JSON, nullable=True)
    watch_status: Mapped[str] = mapped_column(
        String(32), nullable=False, default=WATCH_STATUS_PLAN_TO_WATCH
    )
    user_rating: Mapped[float | None] = mapped_column(Numeric(2, 1), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
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

    user: Mapped["User"] = relationship(back_populates="media_titles")
    watch_entries: Mapped[list["MediaWatchEntry"]] = relationship(
        back_populates="media_title", cascade="all, delete-orphan"
    )
