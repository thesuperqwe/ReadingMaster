import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.reading import (
    FinishSessionRequest,
    ReadingEventCreate,
    ReadingEventOut,
    ReadingProgressUpdate,
    ReadingSessionCreate,
    ReadingSessionOut,
)
from app.services.reading_service import finish_session, record_event, start_session, update_progress

router = APIRouter(prefix="/reading", tags=["reading"])


@router.post("/sessions", response_model=ReadingSessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(
    session: SessionDep, user: CurrentUser, data: ReadingSessionCreate
) -> ReadingSessionOut:
    reading_session = await start_session(session, user, data)
    return ReadingSessionOut.model_validate(reading_session)


@router.post("/events", response_model=ReadingEventOut, status_code=status.HTTP_201_CREATED)
async def create_event(
    session: SessionDep, user: CurrentUser, data: ReadingEventCreate
) -> ReadingEventOut:
    return await record_event(session, user, data)


@router.post("/sessions/{session_id}/progress", response_model=ReadingSessionOut)
async def progress(
    session: SessionDep,
    user: CurrentUser,
    session_id: uuid.UUID,
    data: ReadingProgressUpdate,
) -> ReadingSessionOut:
    reading_session = await update_progress(session, user, session_id, data)
    return ReadingSessionOut.model_validate(reading_session)


@router.post("/sessions/{session_id}/finish", response_model=ReadingSessionOut)
async def finish(
    session: SessionDep,
    user: CurrentUser,
    session_id: uuid.UUID,
    data: FinishSessionRequest,
) -> ReadingSessionOut:
    reading_session = await finish_session(session, user, session_id, data)
    return ReadingSessionOut.model_validate(reading_session)
