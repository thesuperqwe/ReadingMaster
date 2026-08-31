import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), index=True, nullable=False
    )
    question: Mapped[str] = mapped_column(Text, nullable=False)
    question_type: Mapped[str | None] = mapped_column(String(30))
    correct_option: Mapped[str | None] = mapped_column(String(10))
    chapter_index: Mapped[int | None] = mapped_column(Integer)
    chapter_title: Mapped[str | None] = mapped_column(String(255))

    book: Mapped["Book"] = relationship(back_populates="quiz_questions")
    options: Mapped[list["QuizOption"]] = relationship(
        back_populates="question", cascade="all, delete-orphan"
    )
    attempts: Mapped[list["QuizAttempt"]] = relationship(
        back_populates="question", cascade="all, delete-orphan"
    )


class QuizOption(Base):
    __tablename__ = "quiz_options"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("quiz_questions.id", ondelete="CASCADE"), index=True, nullable=False
    )
    option_key: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)

    question: Mapped["QuizQuestion"] = relationship(back_populates="options")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    child_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True, nullable=False
    )
    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("quiz_questions.id", ondelete="CASCADE"), index=True, nullable=False
    )
    selected_option: Mapped[str | None] = mapped_column(String(10))
    is_correct: Mapped[bool | None] = mapped_column(Boolean)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    child: Mapped["Child"] = relationship(back_populates="quiz_attempts")
    question: Mapped["QuizQuestion"] = relationship(back_populates="attempts")
