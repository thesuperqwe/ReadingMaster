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
    content_preview: str | None = None


class BookPageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    page_no: int
    content: str
    image_url: str | None
    chapter_index: int | None = None
    chapter_title: str | None = None


class ChapterOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    index: int
    title: str
    word_count: int
    segment_count: int


class ChapterDetailOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    index: int
    title: str
    segments: list[BookPageOut]


class BookDetailOut(BookOut):
    chapters: list[ChapterOut]


class BookOptionCreate(BaseModel):
    option_key: str = Field(min_length=1, max_length=10)
    content: str = Field(min_length=1)


class BookQuestionCreate(BaseModel):
    question: str = Field(min_length=1)
    correct_option: str = Field(min_length=1, max_length=10)
    options: list[BookOptionCreate] = Field(min_length=2)
    chapter_index: int | None = None


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    level: str = Field(min_length=1, max_length=20)
    description: str | None = None
    category: str | None = None
    estimated_minutes: int | None = Field(default=None, ge=1)
    content: str = Field(min_length=1)
    questions: list[BookQuestionCreate] = []

class BookPreviewRequest(BaseModel):
    content: str = Field(min_length=1)

class ParsedChapterOut(BaseModel):
    title: str
    content: str


class ParsedBookOut(BaseModel):
    chapters: list[ParsedChapterOut]


class BookImportChapter(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    content: str = Field(min_length=1)


class BookImportCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    level: str = Field(min_length=1, max_length=20)
    description: str | None = None
    category: str | None = None
    estimated_minutes: int | None = Field(default=None, ge=1)
    chapters: list[BookImportChapter] = Field(min_length=1)
    questions: list[BookQuestionCreate] = []