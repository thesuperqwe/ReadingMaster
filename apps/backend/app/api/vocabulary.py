import uuid

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.word import UserWordOut
from app.services.book_service import list_user_words
from app.services.child_service import get_child_for_parent

router = APIRouter(prefix="/children", tags=["vocabulary"])


@router.get("/{child_id}/words", response_model=list[UserWordOut])
async def get_vocabulary(
    session: SessionDep, user: CurrentUser, child_id: uuid.UUID
) -> list[UserWordOut]:
    await get_child_for_parent(session, child_id, user)
    return await list_user_words(session, child_id)
