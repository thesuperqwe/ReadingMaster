import base64

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser
from app.asr.base import AsrProviderError
from app.asr.factory import get_asr_provider
from app.schemas.asr import AsrTranscribeRequest, AsrTranscribeResponse

router = APIRouter(prefix="/asr", tags=["asr"])


@router.post("/transcribe", response_model=AsrTranscribeResponse)
async def transcribe(
    data: AsrTranscribeRequest,
    user: CurrentUser,
) -> AsrTranscribeResponse:
    try:
        audio = base64.b64decode(data.audio_base64)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid audio base64",
        ) from exc

    try:
        transcript = await get_asr_provider().transcribe(audio, data.mime_type)
    except AsrProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

    return AsrTranscribeResponse(transcript=transcript)
