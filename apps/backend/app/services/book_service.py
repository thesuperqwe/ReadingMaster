import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Book, BookPage, BookWord, QuizOption, QuizQuestion, UserWord, Word
from app.schemas.book import BookCreate
from app.schemas.word import UserWordOut, WordOut
from app.services.chapter_service import chapter_title_for, split_chapters


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
    parts = split_chapters(data.content)
    has_chapters = any(part.title is not None for part in parts)

    pages: list[BookPage] = []
    page_no = 1
    if has_chapters:
        for index, part in enumerate(parts):
            title = chapter_title_for(parts, index) or f"第 {index + 1} 部分"
            raw_pages = [p.strip() for p in part.body.split("\n\n") if p.strip()]
            if not raw_pages and part.body:
                raw_pages = [part.body.strip()]
            for content in raw_pages:
                pages.append(
                    BookPage(
                        page_no=page_no,
                        content=content,
                        chapter_index=index,
                        chapter_title=title,
                    )
                )
                page_no += 1
    else:
        raw_pages = [p.strip() for p in data.content.split("\n\n") if p.strip()]
        if not raw_pages:
            raw_pages = [data.content.strip()]
        for content in raw_pages:
            pages.append(BookPage(page_no=page_no, content=content))
            page_no += 1

    book = Book(
        title=data.title.strip(),
        description=data.description,
        level=data.level,
        category=data.category,
        estimated_minutes=data.estimated_minutes,
        word_count=sum(len(page.content.split()) for page in pages),
        status="PUBLISHED",
    )
    session.add(book)
    await session.flush()

    for page in pages:
        page.book_id = book.id
    session.add_all(pages)
    await session.flush()

    for question_data in data.questions:
        chapter_index = question_data.chapter_index
        chapter_title = chapter_title_for(parts, chapter_index) if has_chapters else None
        question = QuizQuestion(
            book_id=book.id,
            question=question_data.question.strip(),
            question_type="single_choice",
            correct_option=question_data.correct_option.strip(),
            chapter_index=chapter_index,
            chapter_title=chapter_title,
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
