import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, QuizAttempt, QuizOption, QuizQuestion
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
