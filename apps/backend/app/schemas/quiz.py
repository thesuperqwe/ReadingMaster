import uuid

from pydantic import BaseModel, ConfigDict


class QuizOptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    option_key: str
    content: str


class QuizQuestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    question: str
    question_type: str | None
    options: list[QuizOptionOut]
    chapter_index: int | None = None
    chapter_title: str | None = None


class QuizAttemptCreate(BaseModel):
    child_id: uuid.UUID
    question_id: uuid.UUID
    selected_option: str


class QuizAttemptOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    child_id: uuid.UUID
    question_id: uuid.UUID
    selected_option: str | None
    is_correct: bool | None
    correct_option: str | None
