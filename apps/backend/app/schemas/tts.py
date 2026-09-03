from pydantic import BaseModel, Field


class TtsSynthesizeRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    language_code: str = "en-US"


class TtsSynthesizeResponse(BaseModel):
    audio_base64: str
    mime_type: str