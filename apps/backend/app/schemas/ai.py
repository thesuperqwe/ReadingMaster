import uuid

from pydantic import BaseModel, Field


class ExplainWordRequest(BaseModel):
    word: str = Field(min_length=1, max_length=100)
    context: str | None = None


class ExplainWordResponse(BaseModel):
    word: str
    phonetic: str | None = None
    meaning_zh: str | None = None
    simple_definition: str | None = None
    example: str | None = None
    example_translation: str | None = None


class GenerateQuizRequest(BaseModel):
    book_id: uuid.UUID


class AIQuizOption(BaseModel):
    option_key: str
    content: str


class AIQuizQuestion(BaseModel):
    question: str
    correct_option: str
    options: list[AIQuizOption]


class GenerateQuizResponse(BaseModel):
    questions: list[AIQuizQuestion]
