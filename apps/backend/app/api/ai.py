from fastapi import APIRouter, HTTPException, status

from app.ai.base import AIProviderError
from app.api.deps import CurrentUser, SessionDep
from app.schemas.ai import ExplainWordRequest, ExplainWordResponse, GenerateQuizRequest, GenerateQuizResponse, KeyItemsRequest, KeyItemsResponse
from app.services.ai_service import explain_word, extract_key_items, generate_quiz

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/explain-word", response_model=ExplainWordResponse)
async def explain(data: ExplainWordRequest, user: CurrentUser) -> ExplainWordResponse:
    try:
        return await explain_word(data)
    except AIProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/key-items", response_model=KeyItemsResponse)
async def key_items(data: KeyItemsRequest, user: CurrentUser) -> KeyItemsResponse:
    try:
        return await extract_key_items(data)
    except AIProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/generate-quiz", response_model=GenerateQuizResponse)
async def generate(
    data: GenerateQuizRequest,
    session: SessionDep,
    user: CurrentUser,
) -> GenerateQuizResponse:
    try:
        return await generate_quiz(session, data)
    except AIProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
