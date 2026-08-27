import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, BookWord, QuizAttempt, QuizOption, QuizQuestion, UserWord
from app.schemas.quiz import QuizAttemptCreate, QuizAttemptOut, QuizOptionOut, QuizQuestionOut
from app.services.child_service import get_child_for_parent


async def list_quiz(session: AsyncSession, book_id: uuid.UUID) -> list[QuizQuestionOut]:
    book = await session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    questions = await session.scalars(
        select(QuizQuestion).where(QuizQuestion.book_id == book_id).order_by(QuizQuestion.id)
    )
    result = []
    for question in questions:
        options = await session.scalars(
            select(QuizOption).where(QuizOption.question_id == question.id).order_by(QuizOption.option_key)
        )
        result.append(
            QuizQuestionOut(
                id=question.id,
                question=question.question,
                question_type=question.question_type,
                options=[QuizOptionOut.model_validate(option) for option in options],
            )
        )
    return result


async def submit_attempt(
    session: AsyncSession, parent_id: uuid.UUID, data: QuizAttemptCreate
) -> QuizAttemptOut:
    await get_child_for_parent(session, data.child_id, parent_id)

    question = await session.get(QuizQuestion, data.question_id)
    if question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")

    is_correct = question.correct_option == data.selected_option
    attempt = QuizAttempt(
        child_id=data.child_id,
        question_id=data.question_id,
        selected_option=data.selected_option,
        is_correct=is_correct,
    )
    session.add(attempt)
    await session.flush()

    await _record_quiz_result(
        session,
        child_id=data.child_id,
        book_id=question.book_id,
        is_correct=is_correct,
    )

    await session.commit()
    await session.refresh(attempt)

    return QuizAttemptOut(
        id=attempt.id,
        child_id=attempt.child_id,
        question_id=attempt.question_id,
        selected_option=attempt.selected_option,
        is_correct=attempt.is_correct,
        correct_option=question.correct_option,
    )


async def _record_quiz_result(
    session: AsyncSession,
    child_id: uuid.UUID,
    book_id: uuid.UUID,
    is_correct: bool,
) -> None:
    book_words = await session.scalars(
        select(BookWord).where(BookWord.book_id == book_id)
    )

    for book_word in book_words:
        user_word = await session.scalar(
            select(UserWord).where(
                UserWord.child_id == child_id,
                UserWord.word_id == book_word.word_id,
            )
        )
        if user_word is None:
            user_word = UserWord(child_id=child_id, word_id=book_word.word_id)
            session.add(user_word)
            await session.flush()

        if is_correct:
            user_word.correct_count += 1
        else:
            user_word.wrong_count += 1

        attempts = user_word.correct_count + user_word.wrong_count
        user_word.mastery_score = round(user_word.correct_count / attempts, 2) if attempts else 0
        user_word.last_seen_at = datetime.now(timezone.utc)
