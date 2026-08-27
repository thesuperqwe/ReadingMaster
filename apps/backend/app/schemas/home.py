import uuid

from pydantic import BaseModel, ConfigDict


class HomeChildOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    level: str | None


class RecommendedBookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    level: str
    estimated_minutes: int | None


class ContinueReadingOut(BaseModel):
    id: uuid.UUID
    book_id: uuid.UUID
    title: str
    progress: float


class TodayStats(BaseModel):
    reading_minutes: int
    new_words: int


class HomeResponse(BaseModel):
    child: HomeChildOut
    recommended_book: RecommendedBookOut | None
    continue_reading: list[ContinueReadingOut]
    today: TodayStats
