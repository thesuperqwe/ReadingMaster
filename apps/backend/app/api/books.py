import uuid

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.schemas.book import BookDetailOut, BookOut
from app.schemas.quiz import QuizQuestionOut
from app.services.book_service import get_book_or_404, list_books
from app.services.quiz_service import list_quiz

router = APIRouter(prefix="/books", tags=["books"])


@router.get("", response_model=list[BookOut])
async def get_books(session: SessionDep, user: CurrentUser) -> list[BookOut]:
    books = await list_books(session)
    return [BookOut.model_validate(book) for book in books]


@router.get("/{book_id}", response_model=BookDetailOut)
async def get_book(session: SessionDep, user: CurrentUser, book_id: uuid.UUID) -> BookDetailOut:
    book = await get_book_or_404(session, book_id)
    return BookDetailOut.model_validate(book)


@router.get("/{book_id}/quiz", response_model=list[QuizQuestionOut])
async def get_book_quiz(
    session: SessionDep, user: CurrentUser, book_id: uuid.UUID
) -> list[QuizQuestionOut]:
    return await list_quiz(session, book_id)
