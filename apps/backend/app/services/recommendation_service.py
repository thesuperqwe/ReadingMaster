import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, BookWord, Child, QuizAttempt, QuizQuestion, ReadingSession, UserWord


def _level_number(level: str | None) -> int:
    if not level:
        return 0
    digits = "".join(char for char in level if char.isdigit())
    return int(digits) if digits else 0


async def recommend_book(session: AsyncSession, child: Child) -> Book | None:
    books = await session.scalars(
        select(Book).where(Book.status == "PUBLISHED").order_by(Book.created_at)
    )
    book_list = list(books)
    if not book_list:
        return None

    child_level = _level_number(child.reading_level)
    scored = []
    for book in book_list:
        score = await _score_book(session, child, book, child_level)
        scored.append((score, book))

    scored.sort(key=lambda item: (item[0], item[1].created_at), reverse=True)
    return scored[0][1]


async def _score_book(
    session: AsyncSession,
    child: Child,
    book: Book,
    child_level: int,
) -> float:
    level_number = _level_number(book.level)

    if child_level and level_number == child_level:
        level_score = 30.0
    else:
        level_score = max(0.0, 15.0 - abs(level_number - child_level) * 6.0)

    sessions = await session.scalars(
        select(ReadingSession).where(
            ReadingSession.child_id == child.id,
            ReadingSession.book_id == book.id,
        )
    )
    session_list = list(sessions)
    if session_list:
        completed = sum(1 for item in session_list if item.completed)
        completion_rate = completed / len(session_list)
    else:
        completion_rate = 0.0

    quiz_rows = await session.execute(
        select(QuizAttempt)
        .join(QuizQuestion, QuizQuestion.id == QuizAttempt.question_id)
        .where(
            QuizAttempt.child_id == child.id,
            QuizQuestion.book_id == book.id,
        )
    )
    attempts = list(quiz_rows.scalars())
    if attempts:
        correct = sum(1 for attempt in attempts if attempt.is_correct)
        quiz_score = correct / len(attempts)
    else:
        quiz_score = 0.5

    mastery_rows = await session.execute(
        select(func.coalesce(func.avg(UserWord.mastery_score), 0.0))
        .join(BookWord, BookWord.word_id == UserWord.word_id)
        .where(
            UserWord.child_id == child.id,
            BookWord.book_id == book.id,
        )
    )
    mastery_score = float(mastery_rows.scalar_one())

    category_rows = await session.execute(
        select(func.count(ReadingSession.id))
        .join(Book, Book.id == ReadingSession.book_id)
        .where(
            ReadingSession.child_id == child.id,
            ReadingSession.completed.is_(True),
            Book.category == book.category,
        )
    )
    category_affinity = min(3, int(category_rows.scalar_one() or 0))

    return (
        level_score
        + quiz_score * 25.0
        + mastery_score * 25.0
        + category_affinity * 5.0
        + (1.0 - completion_rate) * 20.0
        + (10.0 if not session_list else 0.0)
    )
