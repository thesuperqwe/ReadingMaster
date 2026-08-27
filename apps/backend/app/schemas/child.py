import uuid

from pydantic import BaseModel, ConfigDict, Field


class ChildCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    grade: int | None = None
    reading_level: str | None = None


class ChildOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    parent_id: uuid.UUID
    name: str
    grade: int | None
    reading_level: str | None
    vocabulary_size: int
