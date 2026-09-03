from app.tts.base import TtsProvider, TtsProviderError


class SystemTtsProvider(TtsProvider):
    async def synthesize(self, text: str, language_code: str = "en-US") -> tuple[bytes, str]:
        raise TtsProviderError(
            "System TTS cannot be served by the backend; set TTS_PROVIDER=google "
            "and configure GOOGLE_TTS_API_KEY"
        )