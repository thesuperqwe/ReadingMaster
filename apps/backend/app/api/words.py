from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.word import WordOut
from app.services.book_service import get_word_by_text

router = APIRouter(prefix="/words", tags=["words"])


@router.get("/{word}", response_model=WordOut)
async def get_word(session: SessionDep, user: CurrentUser, word: str) -> WordOut:
    row = await get_word_by_text(session, word)
    return WordOut.model_validate(row)
