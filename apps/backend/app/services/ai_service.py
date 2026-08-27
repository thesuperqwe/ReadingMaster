import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.factory import get_ai_provider
from app.schemas.ai import (
    AIQuizOption,
    AIQuizQuestion,
    ExplainWordRequest,
    ExplainWordResponse,
    GenerateQuizResponse,
)
from app.services.book_service import get_book_or_404


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


async def generate_quiz(session: AsyncSession, book_id: uuid.UUID) -> GenerateQuizResponse:
    book = await get_book_or_404(session, book_id)
    text = "\n\n".join(page.content for page in book.pages)

    provider = get_ai_provider()
    questions_data = await provider.generate_quiz(text)

    questions = []
    for item in questions_data:
        options = [
            AIQuizOption(
                option_key=option["option_key"],
                content=option["content"],
            )
            for option in item["options"]
        ]
        questions.append(
            AIQuizQuestion(
                question=item["question"],
                correct_option=item["correct_option"],
                options=options,
            )
        )

    return GenerateQuizResponse(questions=questions)
