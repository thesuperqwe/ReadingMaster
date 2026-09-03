import difflib
import re
import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import BookPage, Chapter

from app.ai.factory import get_ai_provider
from app.schemas.ai import (
    AIQuizOption,
    AIQuizQuestion,
    ExplainWordRequest,
    ExplainWordResponse,
    GenerateQuizRequest,
    GenerateQuizResponse,
    JudgeAnswerRequest,
    JudgeAnswerResponse,
    JudgeReadAloudRequest,
    JudgeReadAloudResponse,
    KeyItem,
    KeyItemsRequest,
    KeyItemsResponse,
)
from app.services.book_service import get_book_or_404, get_chapter_or_404
from app.services.chapter_service import chapter_title_for, split_chapters



KEY_ITEM_STOPWORDS = {
    "a", "an", "the", "and", "but", "or", "so", "if", "then", "than",
    "that", "this", "these", "those", "he", "she", "it", "they", "we",
    "i", "you", "me", "him", "her", "us", "them", "my", "your", "his",
    "its", "our", "their", "is", "am", "are", "was", "were", "be",
    "been", "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "can", "could", "shall", "should", "may", "might", "must",
    "to", "of", "in", "on", "at", "for", "with", "by", "from", "up",
    "down", "out", "into", "over", "under", "again", "there", "here",
    "not", "no", "yes", "very", "too", "just", "also", "all", "some",
    "any", "many", "much", "more", "most", "one", "two", "three",
    "four", "five", "six", "seven", "eight", "nine", "ten", "about",
    "after", "before", "between", "through", "during", "without",
    "because", "while",
}


async def explain_word(data: ExplainWordRequest) -> ExplainWordResponse:
    provider = get_ai_provider()
    result = await provider.explain_word(data.word, data.context)

    return ExplainWordResponse(
        word=result.get("word") or data.word,
        phonetic=result.get("phonetic"),
        meaning_zh=result.get("meaning_zh"),
        simple_definition=result.get("simple_definition"),
        example=result.get("example"),
        example_translation=result.get("example_translation"),
    )


def _to_ai_question(
    item: dict,
    chapter_index: int | None = None,
    chapter_title: str | None = None,
) -> AIQuizQuestion:
    options = [
        AIQuizOption(
            option_key=option["option_key"],
            content=option["content"],
        )
        for option in item["options"]
    ]
    return AIQuizQuestion(
        question=item["question"],
        correct_option=item["correct_option"],
        options=options,
        chapter_index=chapter_index,
        chapter_title=chapter_title,
    )


async def generate_quiz(session: AsyncSession, data: GenerateQuizRequest) -> GenerateQuizResponse:
    provider = get_ai_provider()
    questions: list[AIQuizQuestion] = []

    if data.book_id is not None:
        book = await get_book_or_404(session, data.book_id)
        chapters = list(
            await session.scalars(
                select(Chapter)
                .where(Chapter.book_id == book.id)
                .order_by(Chapter.index)
            )
        )

        if chapters:
            for chapter in chapters:
                pages = await session.scalars(
                    select(BookPage)
                    .where(
                        BookPage.book_id == book.id,
                        BookPage.chapter_index == chapter.index,
                    )
                    .order_by(BookPage.page_no)
                )
                chapter_text = "\n\n".join(
                    page.content for page in pages if page.content
                )
                if not chapter_text.strip():
                    continue

                title = chapter.title or f"第 {chapter.index + 1} 部分"
                for item in await provider.generate_quiz(chapter_text):
                    questions.append(
                        _to_ai_question(
                            item,
                            chapter_index=chapter.index,
                            chapter_title=title,
                        )
                    )
            return GenerateQuizResponse(questions=questions)

        text = "\n\n".join(page.content for page in book.pages)
    elif data.text:
        text = data.text.strip()
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="book_id or text is required",
        )

    parts = split_chapters(text)
    has_chapters = any(part.title is not None for part in parts)

    if has_chapters:
        for index, part in enumerate(parts):
            if not part.body:
                continue
            title = chapter_title_for(parts, index) or f"第 {index + 1} 部分"
            for item in await provider.generate_quiz(part.body):
                questions.append(_to_ai_question(item, chapter_index=index, chapter_title=title))
    else:
        for item in await provider.generate_quiz(text):
            questions.append(_to_ai_question(item))

    return GenerateQuizResponse(questions=questions)


def _word_set(text: str) -> set[str]:
    return {
        token.lower()
        for token in re.findall(r"[A-Za-z']+", text)
        if token
    }


def _term_words(term: str) -> set[str]:
    return {token for token in re.findall(r"[A-Za-z']+", term.lower()) if token}


def _is_stopword_term(term: str) -> bool:
    words = _term_words(term)
    return len(words) == 1 and next(iter(words)) in KEY_ITEM_STOPWORDS


def _key_item_limit(text: str) -> int:
    word_count = len(_word_set(text))
    if word_count <= 80:
        return 8
    if word_count <= 220:
        return 15
    return 20


def _normalize_key_items(
    items_data: list[dict],
    text: str,
    limit: int,
) -> list[KeyItem]:
    text_words = _word_set(text)
    seen: set[str] = set()
    items: list[KeyItem] = []

    for item in items_data:
        term = " ".join((item.get("term") or "").split())
        if not term:
            continue
        if _term_words(term) - text_words:
            continue
        if _is_stopword_term(term):
            continue
        normalized = term.lower()
        if normalized in seen:
            continue

        seen.add(normalized)
        items.append(
            KeyItem(
                term=term,
                phonetic=item.get("phonetic"),
                meaning_zh=item.get("meaning_zh"),
                simple_definition=item.get("simple_definition"),
            )
        )
        if len(items) >= limit:
            break

    return items


async def extract_key_items(data: KeyItemsRequest) -> KeyItemsResponse:
    provider = get_ai_provider()
    items_data = await provider.extract_key_items(data.text)
    items = _normalize_key_items(items_data, data.text, _key_item_limit(data.text))
    return KeyItemsResponse(items=items)


def _normalize_spoken_text(text: str) -> str:
    return re.sub(r"[^a-z0-9\s']", " ", text.lower())


async def judge_answer(data: JudgeAnswerRequest) -> JudgeAnswerResponse:
    provider = get_ai_provider()
    result = await provider.judge_answer(
        question=data.question,
        student_answer=data.student_answer,
        reference_answer=data.reference_answer,
        context=data.context,
    )
    return JudgeAnswerResponse(
        correct=bool(result.get("correct")),
        feedback=str(result.get("feedback") or ""),
        model_answer=str(result.get("model_answer") or ""),
    )


def judge_read_aloud(data: JudgeReadAloudRequest) -> JudgeReadAloudResponse:
    target = _normalize_spoken_text(data.target_sentence).split()
    student = _normalize_spoken_text(data.student_transcript).split()
    if not target or not student:
        return JudgeReadAloudResponse(
            correct=False,
            feedback="没有听清，请再试一次。",
        )

    ratio = difflib.SequenceMatcher(None, target, student).ratio()
    correct = ratio >= 0.78
    return JudgeReadAloudResponse(
        correct=correct,
        feedback=(
            "读对了，很清楚，真棒！"
            if correct
            else "还差一点，再听一遍，注意句子的节奏和单词。"
        ),
    )


async def get_or_generate_chapter_key_items(
    session: AsyncSession, book_id: uuid.UUID, chapter_index: int
) -> KeyItemsResponse:
    chapter, pages = await get_chapter_or_404(session, book_id, chapter_index)

    if chapter.key_items:
        return KeyItemsResponse(
            items=[KeyItem(**item) for item in chapter.key_items]
        )

    chapter_text = "\n\n".join(page.content for page in pages if page.content)
    if not chapter_text.strip():
        return KeyItemsResponse(items=[])

    provider = get_ai_provider()
    items_data = await provider.extract_key_items(chapter_text)
    items = _normalize_key_items(
        items_data,
        chapter_text,
        _key_item_limit(chapter_text),
    )

    chapter.key_items = [item.model_dump() for item in items]
    await session.commit()

    return KeyItemsResponse(items=items)