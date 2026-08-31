from pydantic import BaseModel


class ParentChildOut(BaseModel):
    name: str
    level: str | None
    grade: int | None


class WeeklyStats(BaseModel):
    books_read: int
    reading_minutes: int
    new_words: int


class AttentionWordOut(BaseModel):
    word: str
    meaning_zh: str | None


class ParentStatsResponse(BaseModel):
    child: ParentChildOut
    weekly: WeeklyStats
    quiz_accuracy: float
    word_mastery: float
    attention_words: list[AttentionWordOut]