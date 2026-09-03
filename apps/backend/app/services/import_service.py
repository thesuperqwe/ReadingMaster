import html
import io
import posixpath
import re
import uuid
import zipfile
from html.parser import HTMLParser
from pathlib import Path
from xml.etree import ElementTree as ET

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


class _HTMLTextExtractor(HTMLParser):
    _BLOCK_TAGS = {
        "p", "div", "section", "article", "h1", "h2", "h3",
        "h4", "h5", "h6", "li", "tr", "blockquote", "pre",
    }
    _SKIP_TAGS = {"script", "style", "head"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._parts: list[str] = []
        self._skip_depth = 0

    def handle_starttag(self, tag: str, attrs: list) -> None:
        tag = tag.lower()
        if tag in self._SKIP_TAGS:
            self._skip_depth += 1

    def handle_startendtag(self, tag: str, attrs: list) -> None:
        if tag.lower() in self._BLOCK_TAGS:
            self._append_break()

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in self._SKIP_TAGS:
            self._skip_depth = max(0, self._skip_depth - 1)
        elif tag in self._BLOCK_TAGS:
            self._append_break()

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        text = html.unescape(data)
        if text.strip():
            self._parts.append(text)

    def _append_break(self) -> None:
        if self._parts and not self._parts[-1].endswith("\n"):
            self._parts.append("\n")

    def text(self) -> str:
        raw = "".join(self._parts)
        return "\n".join(line.strip() for line in raw.splitlines() if line.strip())


def _parse_html_bytes(data: bytes) -> str:
    extractor = _HTMLTextExtractor()
    extractor.feed(data.decode("utf-8", errors="replace"))
    return extractor.text()


def _parse_docx(data: bytes) -> str:
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))

    paragraphs: list[str] = []
    for node in root.iter():
        if node.tag.rsplit("}", 1)[-1].lower() != "p":
            continue
        text = "".join(
            child.text or ""
            for child in node.iter()
            if child.tag.rsplit("}", 1)[-1].lower() == "t"
        ).strip()
        if text:
            paragraphs.append(text)
    return "\n\n".join(paragraphs)


def _resolve_epub_path(base_path: str, href: str) -> str:
    if href.startswith("/"):
        return href.lstrip("/")
    return posixpath.normpath(posixpath.join(posixpath.dirname(base_path), href))


def _is_epub_content_id(item_id: str, href: str) -> bool:
    combined = f"{item_id} {href}".lower()
    skip_tokens = ("cover", "pg-header", "pg-footer", "ncx", "toc", "nav", "wrap")
    return not any(token in combined for token in skip_tokens)


def _is_epub_boilerplate(text: str) -> bool:
    lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
    if not lines:
        return True

    upper = text.upper()
    if "PROJECT GUTENBERG" in upper:
        return True
    if "START OF THE PROJECT GUTENBERG" in upper:
        return True
    if "END OF THE PROJECT GUTENBERG" in upper:
        return True
    if lines[0].lower().startswith("transcriber"):
        return True
    if len(lines) >= 2 and lines[1].lower().startswith("by "):
        return True
    return False


def _epub_chapter_from_text(text: str) -> ParsedChapterOut:
    text = text.strip()
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    title = "正文"
    body = text

    if lines:
        first = lines[0]
        if re.match(r"^\s*chapter\s+\d+\b", first, re.IGNORECASE) or re.fullmatch(
            r"\s*\d{1,3}\s*", first
        ):
            title = first
            body = "\n".join(lines[1:]).strip()

    return ParsedChapterOut(title=title, content=body)


def _parse_epub(data: bytes) -> list[ParsedChapterOut]:
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            container = ET.fromstring(archive.read("META-INF/container.xml"))
            rootfile_path = next(
                element.attrib["full-path"]
                for element in container.iter()
                if element.tag.rsplit("}", 1)[-1].lower() == "rootfile"
            )
            opf = ET.fromstring(archive.read(rootfile_path))

            manifest: dict[str, str] = {}
            for element in opf.iter():
                if element.tag.rsplit("}", 1)[-1].lower() != "item":
                    continue
                item_id = element.attrib.get("id")
                href = element.attrib.get("href")
                if item_id and href:
                    manifest[item_id] = href

            spine: list[tuple[str, str]] = []
            for element in opf.iter():
                if element.tag.rsplit("}", 1)[-1].lower() != "itemref":
                    continue
                idref = element.attrib.get("idref")
                href = manifest.get(idref or "")
                if href:
                    spine.append((idref or "", href))

            chapters: list[ParsedChapterOut] = []
            for item_id, href in spine:
                if not _is_epub_content_id(item_id, href):
                    continue
                path = _resolve_epub_path(rootfile_path, href)
                if path not in archive.namelist():
                    continue
                text = _parse_html_bytes(archive.read(path))
                if _is_epub_boilerplate(text):
                    continue
                chapter = _epub_chapter_from_text(text)
                if chapter.content:
                    chapters.append(chapter)

            if chapters:
                return chapters
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无法解析该 EPUB 文件",
        )

    return [ParsedChapterOut(title="正文", content="")]


def _parse_fb2(data: bytes) -> str:
    root = ET.fromstring(data)
    paragraphs: list[str] = []
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1].lower() != "p":
            continue
        text = "".join(element.itertext()).strip()
        if text:
            paragraphs.append(text)
    return "\n\n".join(paragraphs)


def parse_text(content: str) -> ParsedBookOut:
    return ParsedBookOut(chapters=_parse_text(content))


def parse_ebook(filename: str, data: bytes) -> ParsedBookOut:
    suffix = Path(filename).suffix.lower()
    if suffix == ".pdf":
        chapters = _parse_pdf(data)
    elif suffix in (".txt", ".md"):
        chapters = _parse_text(data.decode("utf-8", errors="replace"))
    elif suffix in (".html", ".htm"):
        chapters = _parse_text(_parse_html_bytes(data))
    elif suffix == ".epub":
        chapters = _parse_epub(data)
    elif suffix == ".docx":
        chapters = _parse_text(_parse_docx(data))
    elif suffix == ".fb2":
        chapters = _parse_text(_parse_fb2(data))
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