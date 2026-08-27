import uuid

from sqlalchemy import Boolean, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Word(Base):
    __tablename__ = "words"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    word: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    phonetic: Mapped[str | None] = mapped_column(String(100))
    meaning_zh: Mapped[str | None] = mapped_column(Text)
    simple_definition: Mapped[str | None] = mapped_column(Text)
    example_sentence: Mapped[str | None] = mapped_column(Text)
    example_translation: Mapped[str | None] = mapped_column(Text)
    audio_url: Mapped[str | None] = mapped_column(Text)
    part_of_speech: Mapped[str | None] = mapped_column(String(50))

    book_words: Mapped[list["BookWord"]] = relationship(
        back_populates="word", cascade="all, delete-orphan"
    )
    user_words: Mapped[list["UserWord"]] = relationship(
        back_populates="word", cascade="all, delete-orphan"
    )


class BookWord(Base):
    __tablename__ = "book_words"

    book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("books.id", ondelete="CASCADE"), primary_key=True
    )
    word_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("words.id", ondelete="CASCADE"), primary_key=True
    )
    is_key_word: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )

    book: Mapped["Book"] = relationship(back_populates="book_words")
    word: Mapped["Word"] = relationship(back_populates="book_words")
