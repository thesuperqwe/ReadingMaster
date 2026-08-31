import re
from dataclasses import dataclass

_HEADING_PATTERNS = [
    re.compile(r"^\s*chapter\s+\d+\b", re.IGNORECASE),
    re.compile(r"^\s*chapter\s+[ivxlcdm]+\b", re.IGNORECASE),
    re.compile(r"^\s*part\s+\d+\b", re.IGNORECASE),
    re.compile(r"^\s*part\s+[ivxlcdm]+\b", re.IGNORECASE),
    re.compile(r"^\s*第\s*[一二三四五六七八九十百千\d]+\s*[章节回]", re.IGNORECASE),
    re.compile(r"^\s*[ivxlcdm]{1,7}\s*$", re.IGNORECASE),
    re.compile(r"^\s*\d{1,3}\s*$"),
]

# Line immediately following a chapter heading that reads as a one-line summary
# or caption (e.g. "[ Chapter 1 ]\n    - we are introduced to the narrator...").
# It is machine-generated noise, not book prose, so drop it from the body.
_CAPTION_RE = re.compile(r"^\s*-\s+")

SEGMENT_TARGET_WORDS = 140


@dataclass
class ChapterPart:
    title: str | None
    body: str


def _clean_heading(line: str) -> str:
    return line.strip().strip("[]").strip()


def _is_heading(line: str) -> bool:
    cleaned = _clean_heading(line)
    if not cleaned:
        return False
    return any(pattern.match(cleaned) for pattern in _HEADING_PATTERNS)


def split_chapters(content: str) -> list[ChapterPart]:
    """Split text into ordered chapter parts by common chapter headings."""
    parts: list[ChapterPart] = []
    current_title: str | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_title, current_lines
        body = "\n".join(current_lines).strip()
        parts.append(ChapterPart(title=current_title, body=body))
        current_title = None
        current_lines = []

    for line in content.splitlines():
        if _is_heading(line):
            if current_lines or current_title is not None:
                flush()
            current_title = _clean_heading(line)
        elif current_title is not None and not current_lines and _CAPTION_RE.match(line):
            continue
        else:
            current_lines.append(line)

    flush()
    parts = [part for part in parts if part.title is not None or part.body]

    if len(parts) > 1 and parts[0].title is None:
        parts = parts[1:]

    return parts


def chapter_title_for(parts: list[ChapterPart], index: int | None) -> str | None:
    if index is None or index < 0 or index >= len(parts):
        return None
    title = parts[index].title
    if title is not None:
        return title
    return "正文"


def segment_text(text: str, target_words: int = SEGMENT_TARGET_WORDS) -> list[str]:
    """Split body text into reading segments of roughly target_words words."""
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text.strip()) if p.strip()]
    if not paragraphs:
        return []

    segments: list[str] = []
    buffer: list[str] = []
    buffer_words = 0

    def flush() -> None:
        nonlocal buffer, buffer_words
        if buffer:
            segments.append("\n\n".join(buffer))
            buffer = []
            buffer_words = 0

    for paragraph in paragraphs:
        for piece in _split_paragraph(paragraph, target_words):
            words = len(piece.split())
            if buffer_words and buffer_words + words > target_words:
                flush()
            buffer.append(piece)
            buffer_words += words
            if buffer_words >= target_words:
                flush()

    flush()
    return segments


def _split_paragraph(paragraph: str, target_words: int) -> list[str]:
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", paragraph) if s.strip()]
    if not sentences:
        return []
    pieces: list[str] = []
    for sentence in sentences:
        pieces.extend(_chunk_words(sentence, target_words))
    return pieces


def _chunk_words(text: str, target_words: int) -> list[str]:
    words = text.split()
    if len(words) <= target_words:
        return [text]
    return [" ".join(words[i : i + target_words]) for i in range(0, len(words), target_words)]