import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.book import BookCreate, BookDetailOut, BookOut
from app.schemas.quiz import QuizQuestionOut
from app.services.book_service import create_book, delete_book, get_book_or_404, list_books
from app.services.quiz_service import list_quiz

router = APIRouter(prefix="/books", tags=["books"])


def _content_preview(book) -> str | None:
    for page in book.pages:
        text = (page.content or "").strip()
        if text:
            return text[:160]
    return None


@router.get("", response_model=list[BookOut])
async def get_books(session: SessionDep, user: CurrentUser) -> list[BookOut]:
    books = await list_books(session)
    return [
        BookOut(
            id=book.id,
            title=book.title,
            description=book.description,
            level=book.level,
            estimated_minutes=book.estimated_minutes,
            word_count=book.word_count,
            category=book.category,
            status=book.status,
            content_preview=_content_preview(book),
        )
        for book in books
    ]


@router.post("", response_model=BookOut, status_code=status.HTTP_201_CREATED)
async def add_book(session: SessionDep, user: CurrentUser, data: BookCreate) -> BookOut:
    book = await create_book(session, data)
    return BookOut.model_validate(book)


@router.get("/{book_id}", response_model=BookDetailOut)
async def get_book(session: SessionDep, user: CurrentUser, book_id: uuid.UUID) -> BookDetailOut:
    book = await get_book_or_404(session, book_id)
    return BookDetailOut.model_validate(book)


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_book(session: SessionDep, user: CurrentUser, book_id: uuid.UUID) -> None:
    await delete_book(session, book_id)


@router.get("/{book_id}/quiz", response_model=list[QuizQuestionOut])
async def get_book_quiz(
    session: SessionDep, user: CurrentUser, book_id: uuid.UUID
) -> list[QuizQuestionOut]:
    return await list_quiz(session, book_id)