from abc import ABC, abstractmethod


class TtsProviderError(RuntimeError):
    """Raised when a TTS provider cannot synthesize speech."""


class TtsProvider(ABC):
    @abstractmethod
    async def synthesize(self, text: str, language_code: str = "en-US") -> tuple[bytes, str]:
        """Return audio bytes and a MIME type such as audio/mpeg."""