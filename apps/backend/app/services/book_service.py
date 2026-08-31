import uuid

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Book, BookPage, BookWord, Chapter, QuizOption, QuizQuestion, UserWord, Word
from app.schemas.book import BookCreate
from app.schemas.word import UserWordOut, WordOut
from app.services.chapter_service import chapter_title_for, segment_text, split_chapters


def _build_chapters_and_pages(
    book_id: uuid.UUID, parts: list
) -> tuple[list[Chapter], list[BookPage], int]:
    chapters: list[Chapter] = []
    pages: list[BookPage] = []
    page_no = 1
    total_words = 0

    for index, part in enumerate(parts):
        title = chapter_title_for(parts, index)
        segments = segment_text(part.body)
        if not segments:
            continue
        chapter_words = sum(len(segment.split()) for segment in segments)
        chapters.append(
            Chapter(
                book_id=book_id,
                index=index,
                title=title,
                word_count=chapter_words,
                segment_count=len(segments),
            )
        )
        for segment in segments:
            pages.append(
                BookPage(
                    book_id=book_id,
                    page_no=page_no,
                    content=segment,
                    chapter_index=index,
                    chapter_title=title,
                )
            )
            page_no += 1
            total_words += len(segment.split())

    return chapters, pages, total_words


async def list_books(session: AsyncSession) -> list[Book]:
    rows = await session.scalars(
        select(Book)
        .options(selectinload(Book.pages))
        .where(Book.status == "PUBLISHED")
        .order_by(Book.level, Book.title)
    )
    return list(rows)


async def get_book_or_404(session: AsyncSession, book_id: uuid.UUID) -> Book:
    book = await session.scalar(
        select(Book).options(selectinload(Book.pages)).where(Book.id == book_id)
    )
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    return book


async def get_book_with_chapters_or_404(session: AsyncSession, book_id: uuid.UUID) -> Book:
    book = await session.scalar(
        select(Book)
        .options(selectinload(Book.chapters))
        .where(Book.id == book_id)
    )
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    return book


async def get_chapter_or_404(
    session: AsyncSession, book_id: uuid.UUID, chapter_index: int
) -> tuple[Chapter, list[BookPage]]:
    book = await session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    chapter = await session.scalar(
        select(Chapter).where(
            Chapter.book_id == book_id, Chapter.index == chapter_index
        )
    )
    if chapter is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chapter not found")

    pages = await session.scalars(
        select(BookPage)
        .where(BookPage.book_id == book_id, BookPage.chapter_index == chapter_index)
        .order_by(BookPage.page_no)
    )
    return chapter, list(pages)


async def list_book_segments(session: AsyncSession, book_id: uuid.UUID) -> list[BookPage]:
    book = await session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    pages = await session.scalars(
        select(BookPage).where(BookPage.book_id == book_id).order_by(BookPage.page_no)
    )
    return list(pages)

async def delete_book(session: AsyncSession, book_id: uuid.UUID) -> None:
    book = await session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    await session.delete(book)
    await session.commit()


async def create_book(session: AsyncSession, data: BookCreate) -> Book:
    book = Book(
        title=data.title.strip(),
        description=data.description,
        level=data.level,
        category=data.category,
        estimated_minutes=data.estimated_minutes,
        word_count=0,
        status="PUBLISHED",
    )
    session.add(book)
    await session.flush()

    parts = split_chapters(data.content)
    chapters, pages, word_count = _build_chapters_and_pages(book.id, parts)
    book.word_count = word_count
    session.add_all(chapters)
    session.add_all(pages)
    await session.flush()

    has_chapters = any(part.title is not None for part in parts)
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


async def resegment_book(session: AsyncSession, book_id: uuid.UUID) -> Book:
    book = await session.scalar(
        select(Book)
        .options(selectinload(Book.pages), selectinload(Book.chapters))
        .where(Book.id == book_id)
    )
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    content = "\n\n".join(page.content for page in book.pages)
    parts = split_chapters(content)

    await session.execute(delete(BookPage).where(BookPage.book_id == book_id))
    await session.execute(delete(Chapter).where(Chapter.book_id == book_id))

    chapters, pages, word_count = _build_chapters_and_pages(book.id, parts)
    book.word_count = word_count
    session.add_all(chapters)
    session.add_all(pages)

    await session.commit()
    await session.refresh(book)
    return book


async def get_word_by_text(session: AsyncSession, word: str) -> Word:
    normalized = word.strip().lower()
    row = await session.scalar(select(Word).where(Word.word == normalized))
    if row is None:
        return Word(word=normalized)
    return row


async def set_word_favorite(
    session: AsyncSession, child_id: uuid.UUID, word_text: str, favorite: bool
) -> UserWordOut:
    normalized = word_text.strip().lower()
    word = await session.scalar(select(Word).where(Word.word == normalized))
    if word is None:
        word = Word(word=normalized)
        session.add(word)
        await session.flush()

    user_word = await session.scalar(
        select(UserWord).where(
            UserWord.child_id == child_id,
            UserWord.word_id == word.id,
        )
    )
    if user_word is None:
        user_word = UserWord(child_id=child_id, word_id=word.id)
        session.add(user_word)
        await session.flush()

    user_word.favorite = favorite
    await session.commit()
    await session.refresh(user_word)

    return UserWordOut(
        id=user_word.id,
        word=WordOut.model_validate(word),
        mastery_score=user_word.mastery_score,
        encounter_count=user_word.encounter_count,
        click_count=user_word.click_count,
        audio_count=user_word.audio_count,
        correct_count=user_word.correct_count,
        wrong_count=user_word.wrong_count,
        favorite=user_word.favorite,
    )


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
                id=user_word.id,
                word=WordOut.model_validate(word),
                mastery_score=user_word.mastery_score,
                encounter_count=user_word.encounter_count,
                click_count=user_word.click_count,
                audio_count=user_word.audio_count,
                correct_count=user_word.correct_count,
                wrong_count=user_word.wrong_count,
                favorite=user_word.favorite,
            )
        )
    return result