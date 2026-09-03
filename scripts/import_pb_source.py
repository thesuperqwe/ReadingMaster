from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = ROOT / "apps" / "backend"
SCRIPTS_DIR = ROOT / "scripts"
DEFAULT_SOURCE = Path.home() / "AppData" / "Local" / "Temp" / "ReadingMaster-pb-source"
DEFAULT_OUTPUT = SCRIPTS_DIR / "pb_source_seed.json"
REPO_URL = "https://github.com/global-asp/pb-source.git"

LEVELS = ("LEVEL_1", "LEVEL_2", "LEVEL_3", "LEVEL_4")


def _normalize_chunk(chunk: str) -> str:
    paragraphs: list[str] = []
    for raw_paragraph in re.split(r"\n\s*\n", chunk.strip()):
        if not raw_paragraph.strip():
            continue
        text = " ".join(
            line.strip() for line in raw_paragraph.splitlines() if line.strip()
        )
        text = re.sub(r"^\s*#+\s*", "", text)
        text = re.sub(r"[*_`]+", "", text).strip()
        if text:
            paragraphs.append(text)
    return "\n\n".join(paragraphs)


def _metadata_value(line: str) -> tuple[str, str] | None:
    match = re.match(r"^\s*\*\s*([^:]+):\s*(.*)$", line)
    if not match:
        return None
    key = match.group(1).strip().lower()
    value = match.group(2).strip()
    return key, value


def _looks_like_metadata(chunk: str) -> bool:
    for line in chunk.splitlines():
        pair = _metadata_value(line)
        if pair and pair[0] in {"license", "language"}:
            return True
    return False


def parse_story_file(path: Path) -> dict[str, object] | None:
    raw = path.read_text(encoding="utf-8")
    title: str | None = None
    for line in raw.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            title = stripped.lstrip("#").strip()
            break
    if not title:
        return None

    chunks = re.split(r"(?m)^\s*##\s*$", raw)
    pages: list[str] = []
    metadata: dict[str, str] = {}

    for chunk in chunks[1:]:
        if not chunk.strip():
            continue
        if _looks_like_metadata(chunk):
            for line in chunk.splitlines():
                pair = _metadata_value(line)
                if pair:
                    metadata.setdefault(pair[0], pair[1])
            continue
        normalized = _normalize_chunk(chunk)
        if normalized:
            pages.append(normalized)

    body = "\n\n".join(pages)
    word_count = len(re.findall(r"\b[\w'-]+\b", body))
    if not pages or word_count == 0:
        return None

    return {
        "source_id": path.stem.split("_", 1)[0],
        "filename": path.name,
        "title": title,
        "license": metadata.get("license", ""),
        "author": metadata.get("text", ""),
        "illustrator": metadata.get("illustration", ""),
        "translator": metadata.get("translation", ""),
        "language": metadata.get("language", "en"),
        "pages": pages,
        "word_count": word_count,
    }


def _license_is_allowed(license_text: str) -> bool:
    normalized = re.sub(r"[^a-z0-9-]", "", license_text.lower())
    return normalized in {
        "cc-by",
        "ccby",
        "cc-by40",
        "ccby40",
        "publicdomain",
        "public-domain",
        "cc0",
    }


def _level_for_word_count(word_count: int) -> str | None:
    if word_count <= 80:
        return "LEVEL_1"
    if word_count <= 220:
        return "LEVEL_2"
    if word_count <= 500:
        return "LEVEL_3"
    if word_count <= 1000:
        return "LEVEL_4"
    return None


def _description_for(license_text: str, author: str) -> str:
    license_label = license_text or "CC-BY"
    author_part = f" Text by {author}." if author else ""
    return f"A Pratham Books story. License: {license_label}.{author_part}"


def _book_payload(story: dict[str, object]) -> dict[str, object]:
    license_text = str(story["license"])
    author = str(story.get("author", ""))
    return {
        "source_id": story["source_id"],
        "source_url": (
            "https://raw.githubusercontent.com/global-asp/pb-source/master/en/"
            f"{story['filename']}"
        ),
        "title": story["title"],
        "level": story["level"],
        "description": _description_for(license_text, author),
        "category": "story",
        "estimated_minutes": max(1, round(int(story["word_count"]) / 80)),
        "license": license_text,
        "chapters": [
            {
                "title": "正文",
                "content": "\n\n".join(str(page) for page in story["pages"]),
            }
        ],
    }


def _select_balanced(parsed: list[dict[str, object]], limit: int) -> list[dict[str, object]]:
    by_level: dict[str, list[dict[str, object]]] = {level: [] for level in LEVELS}
    for story in parsed:
        by_level[str(story["level"])].append(story)

    selected: list[dict[str, object]] = []
    quota = max(1, limit // len(LEVELS))
    for level in LEVELS:
        candidates = sorted(
            by_level[level],
            key=lambda item: (int(item["word_count"]), str(item["source_id"])),
        )
        selected.extend(candidates[:quota])

    if len(selected) < limit:
        selected_ids = {str(item["filename"]) for item in selected}
        remaining = sorted(
            (item for item in parsed if str(item["filename"]) not in selected_ids),
            key=lambda item: (int(item["word_count"]), str(item["source_id"])),
        )
        selected.extend(remaining[: limit - len(selected)])

    selected.sort(key=lambda item: (str(item["level"]), str(item["source_id"])))
    return selected[:limit]


def collect_books(
    source: Path,
    limit: int,
    min_words: int,
    max_words: int,
) -> list[dict[str, object]]:
    english_dir = source / "en"
    if not english_dir.is_dir():
        raise FileNotFoundError(f"English story directory not found: {english_dir}")

    parsed: list[dict[str, object]] = []
    for path in sorted(english_dir.glob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        story = parse_story_file(path)
        if not story:
            continue
        if not _license_is_allowed(str(story["license"])):
            continue
        word_count = int(story["word_count"])
        if word_count < min_words or word_count > max_words:
            continue
        level = _level_for_word_count(word_count)
        if level is None:
            continue
        story["level"] = level
        parsed.append(story)

    return _select_balanced(parsed, limit)


def ensure_source(source: Path, clone: bool) -> None:
    if source.exists() and (source / "en").is_dir():
        return
    if not clone:
        raise FileNotFoundError(
            f"pb-source not found at {source}. Pass --clone to download it."
        )
    source.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "clone", "--depth", "1", REPO_URL, str(source)],
        check=True,
    )


def write_seed_json(books: list[dict[str, object]], output: Path) -> None:
    payload = {
        "schema_version": 1,
        "source_repo": REPO_URL,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "books": [_book_payload(story) for story in books],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


async def load_seed_json(seed_json: Path) -> int:
    sys.path.insert(0, str(BACKEND_DIR))

    from sqlalchemy import select

    from app.db.session import async_session_factory
    from app.models import Book
    from app.schemas.book import BookImportChapter, BookImportCreate
    from app.services.import_service import create_book_from_chapters

    data = json.loads(seed_json.read_text(encoding="utf-8"))
    books = data.get("books", [])
    imported = 0

    async with async_session_factory() as session:
        for item in books:
            title = str(item["title"]).strip()
            existing = await session.scalar(select(Book).where(Book.title == title))
            if existing is not None:
                continue

            chapters = [
                BookImportChapter(
                    title=str(chapter["title"]),
                    content=str(chapter["content"]),
                )
                for chapter in item["chapters"]
            ]
            await create_book_from_chapters(
                session,
                BookImportCreate(
                    title=title,
                    level=str(item["level"]),
                    description=str(item.get("description") or ""),
                    category=str(item.get("category") or "story"),
                    estimated_minutes=int(item.get("estimated_minutes") or 1),
                    chapters=chapters,
                    questions=[],
                ),
            )
            imported += 1

    return imported


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import CC-BY/Public Domain stories from global-asp/pb-source.",
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=24)
    parser.add_argument("--min-words", type=int, default=20)
    parser.add_argument("--max-words", type=int, default=1000)
    parser.add_argument("--clone", action="store_true")
    parser.add_argument("--write-json", action="store_true")
    parser.add_argument("--load-db", action="store_true")
    args = parser.parse_args()

    ensure_source(args.source, args.clone)
    books = collect_books(args.source, args.limit, args.min_words, args.max_words)
    if not books:
        print("No matching CC-BY/Public Domain stories found.")
        return

    if args.write_json:
        write_seed_json(books, args.output)
        print(f"wrote {len(books)} books to {args.output}")
    else:
        for book in books:
            print(
                f"{book['source_id']}\t{book['level']}\t"
                f"{book['word_count']}\t{book['title']}"
            )

    if args.load_db:
        import asyncio

        if not args.write_json:
            write_seed_json(books, args.output)
        imported = asyncio.run(load_seed_json(args.output))
        print(f"imported {imported} books into the database")


if __name__ == "__main__":
    main()
