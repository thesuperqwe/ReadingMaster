import uuid

from pydantic import BaseModel, ConfigDict, Field


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


class BookOptionCreate(BaseModel):
    option_key: str = Field(min_length=1, max_length=10)
    content: str = Field(min_length=1)


class BookQuestionCreate(BaseModel):
    question: str = Field(min_length=1)
    correct_option: str = Field(min_length=1, max_length=10)
    options: list[BookOptionCreate] = Field(min_length=2)


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    level: str = Field(min_length=1, max_length=20)
    description: str | None = None
    category: str | None = None
    estimated_minutes: int | None = Field(default=None, ge=1)
    content: str = Field(min_length=1)
    questions: list[BookQuestionCreate] = []
