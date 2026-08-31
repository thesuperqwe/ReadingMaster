import re
from dataclasses import dataclass

_HEADING_PATTERNS = [
    re.compile(r"^\s*chapter\s+\d+\b", re.IGNORECASE),
    re.compile(r"^\s*chapter\s+[ivxlcdm]+\b", re.IGNORECASE),
    re.compile(r"^\s*第\s*[一二三四五六七八九十百千\d]+\s*[章节回]", re.IGNORECASE),
]


@dataclass
class ChapterPart:
    title: str | None
    body: str


def _is_heading(line: str) -> bool:
    return any(pattern.match(line) for pattern in _HEADING_PATTERNS)


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
            current_title = line.strip()
        else:
            current_lines.append(line)

    flush()
    return [part for part in parts if part.title is not None or part.body]


def chapter_title_for(parts: list[ChapterPart], index: int | None) -> str | None:
    if index is None or index < 0 or index >= len(parts):
        return None
    title = parts[index].title
    if title is not None:
        return title
    return "前言" if index == 0 else f"第 {index + 1} 部分"