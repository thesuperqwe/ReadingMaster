import uuid
from datetime import datetime

from pydantic import BaseModel


class ReviewWordOut(BaseModel):
    word_id: uuid.UUID
    word: str
    phonetic: str | None
    meaning_zh: str | None
    simple_definition: str | None
    example_sentence: str | None
    example_translation: str | None
    part_of_speech: str | None
    cloze: str | None


class ReviewSubmitRequest(BaseModel):
    word_id: uuid.UUID
    correct: bool


class ReviewResultOut(BaseModel):
    word_id: uuid.UUID
    review_stage: int
    next_review_at: datetime | None
    mastered: bool
    correct_count: int
    wrong_count: int