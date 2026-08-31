from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Child, QuizAttempt, ReadingSession, UserWord, Word
from app.schemas.stats import (
    AttentionWordOut,
    ParentChildOut,
    ParentStatsResponse,
    WeeklyStats,
)


async def build_parent_stats(session: AsyncSession, child: Child) -> ParentStatsResponse:
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    books_read = await session.scalar(
        select(func.count(func.distinct(ReadingSession.book_id))).where(
            ReadingSession.child_id == child.id,
            ReadingSession.completed.is_(True),
            ReadingSession.finished_at >= week_ago,
        )
    )
    reading_seconds = await session.scalar(
        select(func.coalesce(func.sum(ReadingSession.duration_seconds), 0)).where(
            ReadingSession.child_id == child.id,
            ReadingSession.last_activity_at >= week_ago,
        )
    )
    new_words = await session.scalar(
        select(func.count(UserWord.id)).where(
            UserWord.child_id == child.id,
            UserWord.created_at >= week_ago,
        )
    )

    total_attempts = await session.scalar(
        select(func.count(QuizAttempt.id)).where(QuizAttempt.child_id == child.id)
    )
    correct_attempts = await session.scalar(
        select(func.count(QuizAttempt.id)).where(
            QuizAttempt.child_id == child.id,
            QuizAttempt.is_correct.is_(True),
        )
    )
    quiz_accuracy = round(correct_attempts / total_attempts, 2) if total_attempts else 0.0

    average_mastery = await session.scalar(
        select(func.avg(UserWord.mastery_score)).where(UserWord.child_id == child.id)
    )
    word_mastery = round(float(average_mastery or 0.0), 2)

    attention_rows = await session.execute(
        select(UserWord, Word)
        .join(Word, Word.id == UserWord.word_id)
        .where(UserWord.child_id == child.id)
        .where(UserWord.mastery_score < 0.5)
        .order_by(UserWord.mastery_score.asc(), UserWord.wrong_count.desc())
        .limit(5)
    )
    attention_words = [
        AttentionWordOut(word=word.word, meaning_zh=word.meaning_zh)
        for _, word in attention_rows
    ]

    return ParentStatsResponse(
        child=ParentChildOut(
            name=child.name,
            level=child.reading_level,
            grade=child.grade,
        ),
        weekly=WeeklyStats(
            books_read=int(books_read or 0),
            reading_minutes=int((reading_seconds or 0) // 60),
            new_words=int(new_words or 0),
        ),
        quiz_accuracy=quiz_accuracy,
        word_mastery=word_mastery,
        attention_words=attention_words,
    )