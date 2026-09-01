import uuid

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.review import ReviewResultOut, ReviewSubmitRequest, ReviewWordOut
from app.schemas.word import UserWordOut, WordFavoriteRequest
from app.services.book_service import get_user_word, list_user_words, set_word_favorite
from app.services.child_service import get_child_for_parent
from app.services.review_service import list_due_review_words, submit_review

router = APIRouter(prefix="/children", tags=["vocabulary"])


@router.get("/{child_id}/words", response_model=list[UserWordOut])
async def get_vocabulary(
    session: SessionDep, user: CurrentUser, child_id: uuid.UUID
) -> list[UserWordOut]:
    await get_child_for_parent(session, child_id, user)
    return await list_user_words(session, child_id)


@router.get("/{child_id}/words/{word}", response_model=UserWordOut)
async def get_word_status(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID,
    word: str,
) -> UserWordOut:
    await get_child_for_parent(session, child_id, user)
    user_word = await get_user_word(session, child_id, word)
    if user_word is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Word not found")
    return user_word


@router.get("/{child_id}/review", response_model=list[ReviewWordOut])
async def get_review_words(
    session: SessionDep, user: CurrentUser, child_id: uuid.UUID
) -> list[ReviewWordOut]:
    await get_child_for_parent(session, child_id, user)
    return await list_due_review_words(session, child_id)


@router.post("/{child_id}/words/{word}/favorite", response_model=UserWordOut)
async def set_word_favorite_route(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID,
    word: str,
    data: WordFavoriteRequest,
) -> UserWordOut:
    await get_child_for_parent(session, child_id, user)
    return await set_word_favorite(session, child_id, word, data.favorite)


@router.post("/{child_id}/review", response_model=ReviewResultOut)
async def submit_review_word(
    session: SessionDep,
    user: CurrentUser,
    child_id: uuid.UUID,
    data: ReviewSubmitRequest,
) -> ReviewResultOut:
    await get_child_for_parent(session, child_id, user)
    return await submit_review(session, child_id, data)