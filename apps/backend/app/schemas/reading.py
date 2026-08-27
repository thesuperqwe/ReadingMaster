import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReadingSessionCreate(BaseModel):
    child_id: uuid.UUID
    book_id: uuid.UUID


class ReadingSessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    child_id: uuid.UUID
    book_id: uuid.UUID
    started_at: datetime | None
    finished_at: datetime | None
    duration_seconds: int
    progress: float
    completed: bool


class ReadingEventCreate(BaseModel):
    session_id: uuid.UUID
    page_no: int | None = None
    event_type: str = Field(min_length=1, max_length=50)
    word: str | None = None


class ReadingEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    session_id: uuid.UUID | None
    book_id: uuid.UUID
    page_no: int | None
    event_type: str
    word: str | None
    created_at: datetime


class FinishSessionRequest(BaseModel):
    duration_seconds: int = Field(default=0, ge=0)
    progress: float = Field(default=0, ge=0, le=1)
    completed: bool = False
