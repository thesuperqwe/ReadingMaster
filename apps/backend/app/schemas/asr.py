from pydantic import BaseModel, Field


class AsrTranscribeRequest(BaseModel):
    audio_base64: str = Field(min_length=1)
    mime_type: str = "audio/webm"


class AsrTranscribeResponse(BaseModel):
    transcript: str
