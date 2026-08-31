import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Book(Base):
    __tablename__ = "books"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    cover_url: Mapped[str | None] = mapped_column(Text)
    level: Mapped[str] = mapped_column(String(20), nullable=False)
    estimated_minutes: Mapped[int | None] = mapped_column(Integer)
    word_count: Mapped[int | None] = mapped_column(Integer)
    category: Mapped[str | None] = mapped_column(String(100))
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="PUBLISHED", server_default="PUBLISHED"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    pages: Mapped[list["BookPage"]] = relationship(
        back_populates="book", cascade="all, delete-orphan", order_by="BookPage.page_no"
    )
    chapters: Mapped[list["Chapter"]] = relationship(
        back_populates="book", cascade="all, delete-orphan", order_by="Chapter.index"
    )
    book_words: Mapped[list["BookWord"]] = relationship(
        back_populates="book", cascade="all, delete-orphan"
    )
    reading_sessions: Mapped[list["ReadingSession"]] = relationship(
        back_populates="book", passive_deletes=True
    )
    quiz_questions: Mapped[list["QuizQuestion"]] = relationship(
        back_populates="book", cascade="all, delete-orphan"
    )


class BookPage(Base):
    __tablename__ = "book_pages"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), index=True, nullable=False
    )
    page_no: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    image_url: Mapped[str | None] = mapped_column(Text)
    chapter_index: Mapped[int | None] = mapped_column(Integer)
    chapter_title: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    book: Mapped["Book"] = relationship(back_populates="pages")


class Chapter(Base):
    __tablename__ = "chapters"
    __table_args__ = (UniqueConstraint("book_id", "index"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), index=True, nullable=False
    )
    index: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    word_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    segment_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    book: Mapped["Book"] = relationship(back_populates="chapters")