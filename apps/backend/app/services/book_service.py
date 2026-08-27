import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Book, BookPage, BookWord, QuizOption, QuizQuestion, UserWord, Word
from app.schemas.book import BookCreate
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


async def create_book(session: AsyncSession, data: BookCreate) -> Book:
    raw_pages = [page.strip() for page in data.content.split("\n\n") if page.strip()]
    if not raw_pages:
        raw_pages = [data.content.strip()]

    book = Book(
        title=data.title.strip(),
        description=data.description,
        level=data.level,
        category=data.category,
        estimated_minutes=data.estimated_minutes,
        word_count=sum(len(page.split()) for page in raw_pages),
        status="PUBLISHED",
    )
    session.add(book)
    await session.flush()

    session.add_all(
        [
            BookPage(page_no=index + 1, content=page, book_id=book.id)
            for index, page in enumerate(raw_pages)
        ]
    )
    await session.flush()

    for question_data in data.questions:
        question = QuizQuestion(
            book_id=book.id,
            question=question_data.question.strip(),
            question_type="single_choice",
            correct_option=question_data.correct_option.strip(),
        )
        session.add(question)
        await session.flush()
        session.add_all(
            [
                QuizOption(
                    question_id=question.id,
                    option_key=option.option_key.strip(),
                    content=option.content.strip(),
                )
                for option in question_data.options
            ]
        )

    await session.commit()
    await session.refresh(book)
    return book


async def get_word_by_text(session: AsyncSession, word: str) -> Word:
    normalized = word.strip().lower()
    row = await session.scalar(select(Word).where(Word.word == normalized))
    if row is None:
        return Word(word=normalized)
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
