import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ReadingSession(Base):
    __tablename__ = "reading_sessions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    child_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True, nullable=False
    )
    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), index=True, nullable=False
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    progress: Mapped[float] = mapped_column(
        Float, nullable=False, default=0, server_default="0"
    )
    completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    last_activity_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    child: Mapped["Child"] = relationship(back_populates="reading_sessions")
    book: Mapped["Book"] = relationship(back_populates="reading_sessions")
    events: Mapped[list["ReadingEvent"]] = relationship(
        back_populates="session", cascade="all, delete-orphan"
    )


class ReadingEvent(Base):
    __tablename__ = "reading_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("reading_sessions.id", ondelete="CASCADE"), index=True
    )
    child_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True, nullable=False
    )
    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), index=True, nullable=False
    )
    page_no: Mapped[int | None] = mapped_column(Integer)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    word_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("words.id", ondelete="SET NULL"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    session: Mapped["ReadingSession | None"] = relationship(back_populates="events")
    child: Mapped["Child"] = relationship()
    book: Mapped["Book"] = relationship()
    word: Mapped["Word | None"] = relationship()


class UserWord(Base):
    __tablename__ = "user_words"
    __table_args__ = (UniqueConstraint("child_id", "word_id"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    child_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True, nullable=False
    )
    word_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("words.id", ondelete="CASCADE"), index=True, nullable=False
    )
    encounter_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    click_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    audio_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    correct_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    wrong_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    mastery_score: Mapped[float] = mapped_column(
        Float, nullable=False, default=0, server_default="0"
    )
    review_stage: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    mastered: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    favorite: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    child: Mapped["Child"] = relationship(back_populates="user_words")
    word: Mapped["Word"] = relationship(back_populates="user_words")
