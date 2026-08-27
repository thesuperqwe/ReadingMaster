import uuid

from pydantic import BaseModel, ConfigDict


class BookOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str | None
    level: str
    estimated_minutes: int | None
    word_count: int | None
    category: str | None
    status: str


class BookPageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    page_no: int
    content: str
    image_url: str | None


class BookDetailOut(BookOut):
    pages: list[BookPageOut]
