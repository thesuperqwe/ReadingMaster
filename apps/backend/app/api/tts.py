import base64

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser
from app.schemas.tts import TtsSynthesizeRequest, TtsSynthesizeResponse
from app.tts.base import TtsProviderError
from app.tts.factory import get_tts_provider

router = APIRouter(prefix="/tts", tags=["tts"])


@router.post("/synthesize", response_model=TtsSynthesizeResponse)
async def synthesize(data: TtsSynthesizeRequest, user: CurrentUser) -> TtsSynthesizeResponse:
    try:
        audio, mime_type = await get_tts_provider().synthesize(
            data.text,
            language_code=data.language_code,
        )
    except TtsProviderError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    return TtsSynthesizeResponse(
        audio_base64=base64.b64encode(audio).decode(),
        mime_type=mime_type,
    )