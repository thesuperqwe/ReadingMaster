import uuid
from pathlib import Path

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Book, BookPage, Chapter, QuizOption, QuizQuestion
from app.schemas.book import BookImportCreate, ParsedBookOut, ParsedChapterOut
from app.services.chapter_service import chapter_title_for, segment_text, split_chapters


def _parse_text(content: str) -> list[ParsedChapterOut]:
    parts = split_chapters(content)
    return [
        ParsedChapterOut(title=chapter_title_for(parts, index), content=part.body)
        for index, part in enumerate(parts)
    ]


def _parse_pdf(data: bytes) -> list[ParsedChapterOut]:
    import fitz  # pymupdf; lazy import keeps txt import usable without it

    doc = fitz.open(stream=data, filetype="pdf")
    try:
        full_text = "\n\n".join(page.get_text() for page in doc)
        text_chapters = _parse_text(full_text)
        # Splitting by headings inside the extracted text keeps chapter boundaries
        # correct even when a bookmark points at a page that also holds front
        # matter or the previous chapter's closing lines. Only fall back to the
        # PDF bookmarks when no recognizable headings exist in the text.
        if len(text_chapters) > 1:
            return text_chapters

        toc = doc.get_toc()
        if toc:
            entries = [entry for entry in toc if entry[0] <= 1]
            chapters: list[ParsedChapterOut] = []
            for i, entry in enumerate(entries):
                _, title, page = entry
                start = page - 1
                end = entries[i + 1][2] - 1 if i + 1 < len(entries) else doc.page_count
                text = "\n\n".join(
                    doc.load_page(p).get_text() for p in range(start, end)
                )
                if title.strip() and text.strip():
                    chapters.append(ParsedChapterOut(title=title.strip(), content=text.strip()))
            if chapters:
                return chapters

        return text_chapters
    finally:
        doc.close()


def parse_text(content: str) -> ParsedBookOut:
    return ParsedBookOut(chapters=_parse_text(content))


def parse_ebook(filename: str, data: bytes) -> ParsedBookOut:
    suffix = Path(filename).suffix.lower()
    if suffix == ".pdf":
        chapters = _parse_pdf(data)
    elif suffix in (".txt", ".md"):
        chapters = _parse_text(data.decode("utf-8", errors="replace"))
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="不支持的文件类型"
        )
    return ParsedBookOut(chapters=chapters)


async def create_book_from_chapters(
    session: AsyncSession, data: BookImportCreate
) -> Book:
    book = Book(
        title=data.title.strip(),
        description=data.description,
        level=data.level,
        category=data.category,
        estimated_minutes=data.estimated_minutes,
        word_count=0,
        status="PUBLISHED",
    )
    session.add(book)
    await session.flush()

    page_no = 1
    total_words = 0
    chapters: list[Chapter] = []
    pages: list[BookPage] = []

    for index, chapter_data in enumerate(data.chapters):
        title = chapter_data.title.strip()
        segments = segment_text(chapter_data.content)
        chapter_words = sum(len(segment.split()) for segment in segments)
        chapters.append(
            Chapter(
                book_id=book.id,
                index=index,
                title=title,
                word_count=chapter_words,
                segment_count=len(segments),
            )
        )
        for segment in segments:
            pages.append(
                BookPage(
                    book_id=book.id,
                    page_no=page_no,
                    content=segment,
                    chapter_index=index,
                    chapter_title=title,
                )
            )
            page_no += 1
            total_words += len(segment.split())

    book.word_count = total_words
    session.add_all(chapters)
    session.add_all(pages)
    await session.flush()

    for question_data in data.questions:
        chapter_title = None
        if question_data.chapter_index is not None and 0 <= question_data.chapter_index < len(data.chapters):
            chapter_title = data.chapters[question_data.chapter_index].title.strip()
        question = QuizQuestion(
            book_id=book.id,
            question=question_data.question.strip(),
            question_type="single_choice",
            correct_option=question_data.correct_option.strip(),
            chapter_index=question_data.chapter_index,
            chapter_title=chapter_title,
        )
        session.add(question)
        await session.flush()
        session.add_all(
            [
                QuizOption(
                    question_id=question.id,
                    option_key=option.option_key.strip(),
                    content=option.content.strip(),
                )
                for option in question_data.options
            ]
        )

    await session.commit()
    await session.refresh(book)
    return book