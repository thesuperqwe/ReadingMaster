import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, ReadingSession, UserWord
from app.schemas.home import (
    ContinueReadingOut,
    HomeChildOut,
    HomeResponse,
    RecommendedBookOut,
    TodayStats,
)
from app.services.child_service import get_child_for_parent
from app.services.recommendation_service import recommend_book


async def build_home(
    session: AsyncSession, parent_id: uuid.UUID, child_id: uuid.UUID
) -> HomeResponse:
    child = await get_child_for_parent(session, child_id, parent_id)

    recommended_book = await recommend_book(session, child)

    continue_rows = await session.execute(
        select(ReadingSession, Book)
        .join(Book, Book.id == ReadingSession.book_id)
        .where(ReadingSession.child_id == child_id, ReadingSession.completed.is_(False))
        .order_by(ReadingSession.started_at.desc().nulls_last())
        .limit(5)
    )
    continue_reading = [
        ContinueReadingOut(
            id=reading_session.id,
            book_id=book.id,
            title=book.title,
            progress=reading_session.progress,
        )
        for reading_session, book in continue_rows
    ]

    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    reading_seconds = await session.scalar(
        select(func.coalesce(func.sum(ReadingSession.duration_seconds), 0)).where(
            ReadingSession.child_id == child_id,
            ReadingSession.completed.is_(True),
            ReadingSession.finished_at >= today_start,
        )
    )
    new_words = await session.scalar(
        select(func.count(UserWord.id)).where(
            UserWord.child_id == child_id,
            UserWord.created_at >= today_start,
        )
    )

    return HomeResponse(
        child=HomeChildOut(name=child.name, level=child.reading_level),
        recommended_book=(
            RecommendedBookOut.model_validate(recommended_book) if recommended_book else None
        ),
        continue_reading=continue_reading,
        today=TodayStats(
            reading_minutes=int((reading_seconds or 0) // 60),
            new_words=int(new_words or 0),
        ),
    )
