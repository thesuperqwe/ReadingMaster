import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.factory import get_ai_provider
from app.schemas.ai import (
    AIQuizOption,
    AIQuizQuestion,
    ExplainWordRequest,
    ExplainWordResponse,
    GenerateQuizRequest,
    GenerateQuizResponse,
    KeyItem,
    KeyItemsRequest,
    KeyItemsResponse,
)
from app.services.book_service import get_book_or_404, get_chapter_or_404
from app.services.chapter_service import chapter_title_for, split_chapters


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
    if data.book_id is not None:
        book = await get_book_or_404(session, data.book_id)
        text = "\n\n".join(page.content for page in book.pages)
    elif data.text:
        text = data.text.strip()
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="book_id or text is required",
        )

    provider = get_ai_provider()
    parts = split_chapters(text)
    has_chapters = any(part.title is not None for part in parts)

    questions: list[AIQuizQuestion] = []
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


async def extract_key_items(data: KeyItemsRequest) -> KeyItemsResponse:
    provider = get_ai_provider()
    items_data = await provider.extract_key_items(data.text)

    items = [
        KeyItem(
            term=(item.get("term") or "").strip(),
            phonetic=item.get("phonetic"),
            meaning_zh=item.get("meaning_zh"),
            simple_definition=item.get("simple_definition"),
        )
        for item in items_data
        if (item.get("term") or "").strip()
    ]
    return KeyItemsResponse(items=items)


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
    items = [
        KeyItem(
            term=(item.get("term") or "").strip(),
            phonetic=item.get("phonetic"),
            meaning_zh=item.get("meaning_zh"),
            simple_definition=item.get("simple_definition"),
        )
        for item in items_data
        if (item.get("term") or "").strip()
    ]

    chapter.key_items = [item.model_dump() for item in items]
    await session.commit()

    return KeyItemsResponse(items=items)