from pydantic import BaseModel, Field


class OcrImageItem(BaseModel):
    data: str = Field(min_length=1)
    mime_type: str = "image/jpeg"


class OcrRequest(BaseModel):
    images: list[OcrImageItem] = Field(min_length=1)
