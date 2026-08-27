from fastapi import APIRouter, HTTPException, status

from app.ai.base import AIProviderError
from app.api.deps import CurrentUser, SessionDep
from app.schemas.ai import ExplainWordRequest, ExplainWordResponse, GenerateQuizRequest, GenerateQuizResponse
from app.services.ai_service import explain_word, generate_quiz

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/explain-word", response_model=ExplainWordResponse)
async def explain(data: ExplainWordRequest, user: CurrentUser) -> ExplainWordResponse:
    try:
        return await explain_word(data)
    except AIProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/generate-quiz", response_model=GenerateQuizResponse)
async def generate(
    data: GenerateQuizRequest,
    session: SessionDep,
    user: CurrentUser,
) -> GenerateQuizResponse:
    try:
        return await generate_quiz(session, data.book_id)
    except AIProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
