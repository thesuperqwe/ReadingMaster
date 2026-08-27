import uuid

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.review import ReviewResultOut, ReviewSubmitRequest, ReviewWordOut
from app.schemas.word import UserWordOut
from app.services.book_service import list_user_words
from app.services.child_service import get_child_for_parent
from app.services.review_service import list_due_review_words, submit_review

router = APIRouter(prefix="/children", tags=["vocabulary"])


@router.get("/{child_id}/words", response_model=list[UserWordOut])
async def get_vocabulary(
    session: SessionDep, user: CurrentUser, child_id: uuid.UUID
) -> list[UserWordOut]:
    await get_child_for_parent(session, child_id, user)
    return await list_user_words(session, child_id)


@router.get("/{child_id}/review", response_model=list[ReviewWordOut])
async def get_review_words(
    session: SessionDep, user: CurrentUser, child_id: uuid.UUID
) -> list[ReviewWordOut]:
    await get_child_for_parent(session, child_id, user)
    return await list_due_review_words(session, child_id)


@router.post("/{child_id}/review", response_model=ReviewResultOut)
async def submit_review_word(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID,
    data: ReviewSubmitRequest,
) -> ReviewResultOut:
    await get_child_for_parent(session, child_id, user)
    return await submit_review(session, child_id, data)