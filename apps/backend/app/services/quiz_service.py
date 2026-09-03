import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, BookWord, Chapter, QuizAttempt, QuizOption, QuizQuestion, UserWord
from app.schemas.ai import JudgeAnswerRequest
from app.schemas.book import BookQuestionCreate
from app.schemas.quiz import (
    QuizAttemptCreate,
    QuizAttemptOut,
    QuizOptionOut,
    QuizQuestionOut,
    VoiceAttemptCreate,
    VoiceAttemptOut,
)
from app.services.ai_service import judge_answer
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
                chapter_index=question.chapter_index,
                chapter_title=question.chapter_title,
            )
        )
    return result


async def add_question(
    session: AsyncSession,
    book_id: uuid.UUID,
    data: BookQuestionCreate,
) -> QuizQuestionOut:
    book = await session.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    chapter_title = None
    if data.chapter_index is not None:
        chapter = await session.scalar(
            select(Chapter).where(
                Chapter.book_id == book_id,
                Chapter.index == data.chapter_index,
            )
        )
        if chapter is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chapter not found")
        chapter_title = chapter.title

    question = QuizQuestion(
        book_id=book_id,
        question=data.question.strip(),
        question_type="single_choice",
        correct_option=data.correct_option.strip(),
        chapter_index=data.chapter_index,
        chapter_title=chapter_title,
    )
    session.add(question)
    await session.flush()

    options = [
        QuizOption(
            question_id=question.id,
            option_key=option.option_key.strip(),
            content=option.content.strip(),
        )
        for option in data.options
    ]
    session.add_all(options)
    await session.commit()
    await session.refresh(question)

    return QuizQuestionOut(
        id=question.id,
        question=question.question,
        question_type=question.question_type,
        options=[QuizOptionOut.model_validate(option) for option in options],
        chapter_index=question.chapter_index,
        chapter_title=question.chapter_title,
    )


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


async def submit_voice_attempt(
    session: AsyncSession, parent_id: uuid.UUID, data: VoiceAttemptCreate
) -> VoiceAttemptOut:
    await get_child_for_parent(session, data.child_id, parent_id)

    question = await session.get(QuizQuestion, data.question_id)
    if question is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")

    options = await session.scalars(
        select(QuizOption).where(QuizOption.question_id == question.id)
    )
    reference_answer = next(
        (option.content for option in options if option.option_key == question.correct_option),
        None,
    )

    judgement = await judge_answer(
        JudgeAnswerRequest(
            question=question.question,
            student_answer=data.student_answer,
            reference_answer=reference_answer,
        )
    )

    attempt = QuizAttempt(
        child_id=data.child_id,
        question_id=data.question_id,
        selected_option=None,
        is_correct=judgement.correct,
    )
    session.add(attempt)
    await session.flush()

    await _record_quiz_result(
        session,
        child_id=data.child_id,
        book_id=question.book_id,
        is_correct=judgement.correct,
    )

    await session.commit()
    await session.refresh(attempt)

    return VoiceAttemptOut(
        id=attempt.id,
        child_id=attempt.child_id,
        question_id=attempt.question_id,
        student_answer=data.student_answer,
        is_correct=judgement.correct,
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
