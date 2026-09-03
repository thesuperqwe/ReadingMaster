from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.quiz import QuizAttemptCreate, QuizAttemptOut, VoiceAttemptCreate, VoiceAttemptOut
from app.services.quiz_service import submit_attempt, submit_voice_attempt

router = APIRouter(prefix="/quiz", tags=["quiz"])


@router.post("/attempt", response_model=QuizAttemptOut, status_code=status.HTTP_201_CREATED)
async def create_attempt(
    session: SessionDep, user: CurrentUser, data: QuizAttemptCreate
) -> QuizAttemptOut:
    return await submit_attempt(session, user, data)


@router.post("/voice-attempt", response_model=VoiceAttemptOut, status_code=status.HTTP_201_CREATED)
async def create_voice_attempt(
    session: SessionDep, user: CurrentUser, data: VoiceAttemptCreate
) -> VoiceAttemptOut:
    return await submit_voice_attempt(session, user, data)
