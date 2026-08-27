import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Book, BookWord, UserWord, Word
from app.schemas.word import UserWordOut, WordOut


async def list_books(session: AsyncSession) -> list[Book]:
    rows = await session.scalars(
        select(Book).where(Book.status == "PUBLISHED").order_by(Book.level, Book.title)
    )
    return list(rows)


async def get_book_or_404(session: AsyncSession, book_id: uuid.UUID) -> Book:
    book = await session.scalar(
        select(Book).options(selectinload(Book.pages)).where(Book.id == book_id)
    )
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    return book


async def get_word_by_text(session: AsyncSession, word: str) -> Word:
    row = await session.scalar(select(Word).where(Word.word == word.lower()))
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Word not found")
    return row


async def list_user_words(session: AsyncSession, child_id: uuid.UUID) -> list[UserWordOut]:
    rows = await session.execute(
        select(UserWord, Word)
        .join(Word, Word.id == UserWord.word_id)
        .where(UserWord.child_id == child_id)
        .order_by(UserWord.last_seen_at.desc().nulls_last())
    )
    result = []
    for user_word, word in rows:
        result.append(
            UserWordOut(
                word=WordOut.model_validate(word),
                mastery_score=user_word.mastery_score,
                encounter_count=user_word.encounter_count,
                click_count=user_word.click_count,
                audio_count=user_word.audio_count,
                correct_count=user_word.correct_count,
                wrong_count=user_word.wrong_count,
            )
        )
    return result
