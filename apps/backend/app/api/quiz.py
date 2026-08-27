from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.quiz import QuizAttemptCreate, QuizAttemptOut
from app.services.quiz_service import submit_attempt

router = APIRouter(prefix="/quiz", tags=["quiz"])


@router.post("/attempt", response_model=QuizAttemptOut, status_code=status.HTTP_201_CREATED)
async def create_attempt(
    session: SessionDep, user: CurrentUser, data: QuizAttemptCreate
) -> QuizAttemptOut:
    return await submit_attempt(session, user, data)
