import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, ReadingEvent, ReadingSession, UserWord, Word
from app.schemas.reading import (
    FinishSessionRequest,
    ReadingEventCreate,
    ReadingEventOut,
    ReadingProgressUpdate,
    ReadingSessionCreate,
)
from app.services.child_service import get_child_for_parent

WORD_EVENT_TYPES = {"WORD_CLICK", "WORD_AUDIO", "WORD_MEANING"}


async def start_session(
    session: AsyncSession, parent_id: uuid.UUID, data: ReadingSessionCreate
) -> ReadingSession:
    await get_child_for_parent(session, data.child_id, parent_id)
    book = await session.get(Book, data.book_id)
    if book is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    now = datetime.now(timezone.utc)
    reading_session = ReadingSession(
        child_id=data.child_id,
        book_id=data.book_id,
        started_at=now,
        last_activity_at=now,
        duration_seconds=0,
        progress=0,
        completed=False,
    )
    session.add(reading_session)
    await session.commit()
    await session.refresh(reading_session)
    return reading_session


async def record_event(
    session: AsyncSession, parent_id: uuid.UUID, data: ReadingEventCreate
) -> ReadingEventOut:
    reading_session = await session.get(ReadingSession, data.session_id)
    if reading_session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading session not found")

    await get_child_for_parent(session, reading_session.child_id, parent_id)

    word = None
    if data.word:
        normalized = data.word.lower()
        word = await session.scalar(select(Word).where(Word.word == normalized))
        if word is None:
            word = Word(word=normalized)
            session.add(word)
            await session.flush()

    event_type = data.event_type.upper()
    event = ReadingEvent(
        session_id=reading_session.id,
        child_id=reading_session.child_id,
        book_id=reading_session.book_id,
        page_no=data.page_no,
        event_type=event_type,
        word_id=word.id if word else None,
    )
    session.add(event)
    await session.flush()

    if word is not None and event_type in WORD_EVENT_TYPES:
        await _record_user_word(session, reading_session.child_id, word.id, event_type)

    await session.commit()
    await session.refresh(event)

    return ReadingEventOut(
        id=event.id,
        session_id=event.session_id,
        book_id=event.book_id,
        page_no=event.page_no,
        event_type=event.event_type,
        word=word.word if word else None,
        created_at=event.created_at,
    )


async def finish_session(
    session: AsyncSession,
    parent_id: uuid.UUID,
    session_id: uuid.UUID,
    data: FinishSessionRequest,
) -> ReadingSession:
    reading_session = await session.get(ReadingSession, session_id)
    if reading_session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading session not found")

    await get_child_for_parent(session, reading_session.child_id, parent_id)

    now = datetime.now(timezone.utc)
    reading_session.duration_seconds = data.duration_seconds
    reading_session.progress = data.progress
    reading_session.completed = data.completed
    reading_session.finished_at = now
    reading_session.last_activity_at = now

    if data.completed:
        session.add(
            ReadingEvent(
                session_id=reading_session.id,
                child_id=reading_session.child_id,
                book_id=reading_session.book_id,
                event_type="BOOK_FINISH",
            )
        )

    await session.commit()
    await session.refresh(reading_session)
    return reading_session


async def update_progress(
    session: AsyncSession,
    parent_id: uuid.UUID,
    session_id: uuid.UUID,
    data: ReadingProgressUpdate,
) -> ReadingSession:
    reading_session = await session.get(ReadingSession, session_id)
    if reading_session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reading session not found")

    await get_child_for_parent(session, reading_session.child_id, parent_id)

    reading_session.duration_seconds = data.duration_seconds
    reading_session.progress = data.progress
    reading_session.last_activity_at = datetime.now(timezone.utc)

    await session.commit()
    await session.refresh(reading_session)
    return reading_session


async def _record_user_word(
    session: AsyncSession, child_id: uuid.UUID, word_id: uuid.UUID, event_type: str
) -> None:
    user_word = await session.scalar(
        select(UserWord).where(
            UserWord.child_id == child_id,
            UserWord.word_id == word_id,
        )
    )
    if user_word is None:
        user_word = UserWord(child_id=child_id, word_id=word_id)
        session.add(user_word)
        await session.flush()

    user_word.encounter_count += 1
    if event_type == "WORD_CLICK":
        user_word.click_count += 1
    elif event_type == "WORD_AUDIO":
        user_word.audio_count += 1

    user_word.last_seen_at = datetime.now(timezone.utc)
