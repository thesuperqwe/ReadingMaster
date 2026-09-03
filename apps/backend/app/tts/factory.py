from app.core.config import get_settings
from app.tts.base import TtsProvider
from app.tts.google_provider import GoogleTtsProvider
from app.tts.system_provider import SystemTtsProvider


def get_tts_provider() -> TtsProvider:
    settings = get_settings()
    provider_name = settings.tts_provider.strip().lower()

    if provider_name == "google":
        return GoogleTtsProvider(
            api_key=settings.google_tts_api_key,
            access_token=settings.google_tts_access_token,
            voice=settings.google_tts_voice,
            speaking_rate=settings.google_tts_speaking_rate,
            pitch=settings.google_tts_pitch,
        )

    if provider_name == "system":
        return SystemTtsProvider()

    raise ValueError(f"Unsupported TTS provider: {settings.tts_provider}")