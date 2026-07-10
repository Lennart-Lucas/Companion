from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class MediaWatchEntry(Base):
    __tablename__ = "media_watch_entries"

    id: Mapped[int] = mapped_column(primary_key=True)
    media_title_id: Mapped[int] = mapped_column(
        ForeignKey("media_titles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    season_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    episode_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    episode_imdb_id: Mapped[str | None] = mapped_column(String(16), nullable=True)
    episode_title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    watched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
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

    media_title: Mapped["MediaTitle"] = relationship(back_populates="watch_entries")
