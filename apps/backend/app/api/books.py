import uuid

from fastapi import APIRouter, File, UploadFile, status

from app.api.deps import CurrentUser, SessionDep
from app.schemas.ai import KeyItemsResponse
from app.schemas.book import BookCreate, BookDetailOut, BookImportCreate, BookOut, BookPageOut, BookPreviewRequest, ChapterDetailOut, ParsedBookOut
from app.schemas.quiz import QuizQuestionOut
from app.services.book_service import (
    create_book,
    delete_book,
    get_book_with_chapters_or_404,
    get_chapter_or_404,
    list_book_segments,
    list_books,
)
from app.services.ai_service import get_or_generate_chapter_key_items
from app.services.import_service import create_book_from_chapters, parse_ebook, parse_text
from app.services.quiz_service import list_quiz

router = APIRouter(prefix="/books", tags=["books"])


def _content_preview(book) -> str | None:
    for page in book.pages:
        text = " ".join((page.content or "").split())
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


@router.post("/preview", response_model=ParsedBookOut)
async def preview_book(
    user: CurrentUser, data: BookPreviewRequest
) -> ParsedBookOut:
    return parse_text(data.content)

@router.post("/import/parse", response_model=ParsedBookOut)
async def parse_book_file(
    user: CurrentUser, file: UploadFile = File(...)
) -> ParsedBookOut:
    data = await file.read()
    return parse_ebook(file.filename or "book.pdf", data)


@router.post("/import", response_model=BookOut, status_code=status.HTTP_201_CREATED)
async def import_book(
    session: SessionDep, user: CurrentUser, data: BookImportCreate
) -> BookOut:
    book = await create_book_from_chapters(session, data)
    return BookOut.model_validate(book)

@router.get("/{book_id}", response_model=BookDetailOut)
async def get_book(session: SessionDep, user: CurrentUser, book_id: uuid.UUID) -> BookDetailOut:
    book = await get_book_with_chapters_or_404(session, book_id)
    return BookDetailOut.model_validate(book)


@router.get("/{book_id}/chapters/{chapter_index}", response_model=ChapterDetailOut)
async def get_book_chapter(
    session: SessionDep,
    user: CurrentUser,
    book_id: uuid.UUID,
    chapter_index: int,
) -> ChapterDetailOut:
    chapter, pages = await get_chapter_or_404(session, book_id, chapter_index)
    return ChapterDetailOut(
        index=chapter.index,
        title=chapter.title,
        segments=[BookPageOut.model_validate(page) for page in pages],
    )


@router.get("/{book_id}/chapters/{chapter_index}/key-items", response_model=KeyItemsResponse)
async def get_chapter_key_items(
    session: SessionDep,
    user: CurrentUser,
    book_id: uuid.UUID,
    chapter_index: int,
) -> KeyItemsResponse:
    return await get_or_generate_chapter_key_items(session, book_id, chapter_index)


@router.get("/{book_id}/content", response_model=list[BookPageOut])
async def get_book_content(
    session: SessionDep, user: CurrentUser, book_id: uuid.UUID
) -> list[BookPageOut]:
    pages = await list_book_segments(session, book_id)
    return [BookPageOut.model_validate(page) for page in pages]

@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_book(session: SessionDep, user: CurrentUser, book_id: uuid.UUID) -> None:
    await delete_book(session, book_id)


@router.get("/{book_id}/quiz", response_model=list[QuizQuestionOut])
async def get_book_quiz(
    session: SessionDep, user: CurrentUser, book_id: uuid.UUID
) -> list[QuizQuestionOut]:
    return await list_quiz(session, book_id)