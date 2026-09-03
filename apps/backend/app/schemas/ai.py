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
    book_id: uuid.UUID | None = None
    text: str | None = None


class AIQuizOption(BaseModel):
    option_key: str
    content: str


class AIQuizQuestion(BaseModel):
    question: str
    correct_option: str
    options: list[AIQuizOption]
    chapter_index: int | None = None
    chapter_title: str | None = None


class GenerateQuizResponse(BaseModel):
    questions: list[AIQuizQuestion]


class KeyItemsRequest(BaseModel):
    text: str = Field(min_length=1)


class KeyItem(BaseModel):
    term: str
    phonetic: str | None = None
    meaning_zh: str | None = None
    simple_definition: str | None = None


class KeyItemsResponse(BaseModel):
    items: list[KeyItem]


class JudgeAnswerRequest(BaseModel):
    question: str = Field(min_length=1)
    student_answer: str = Field(min_length=1)
    reference_answer: str | None = None
    context: str | None = None


class JudgeAnswerResponse(BaseModel):
    correct: bool
    feedback: str
    model_answer: str


class JudgeReadAloudRequest(BaseModel):
    target_sentence: str = Field(min_length=1)
    student_transcript: str = Field(min_length=1)


class JudgeReadAloudResponse(BaseModel):
    correct: bool
    feedback: str
