import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Child(Base):
    __tablename__ = "children"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    parent_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    grade: Mapped[int | None] = mapped_column(Integer)
    reading_level: Mapped[str | None] = mapped_column(String(20))
    vocabulary_size: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    parent: Mapped["User"] = relationship(back_populates="children")
    reading_sessions: Mapped[list["ReadingSession"]] = relationship(
        back_populates="child", cascade="all, delete-orphan"
    )
    user_words: Mapped[list["UserWord"]] = relationship(
        back_populates="child", cascade="all, delete-orphan"
    )
    quiz_attempts: Mapped[list["QuizAttempt"]] = relationship(
        back_populates="child", cascade="all, delete-orphan"
    )
