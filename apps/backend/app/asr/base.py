from abc import ABC, abstractmethod


class AsrProviderError(RuntimeError):
    """Raised when an ASR provider cannot transcribe audio."""


class AsrProvider(ABC):
    @abstractmethod
    async def transcribe(self, audio: bytes, mime_type: str) -> str:
        """Return the recognized text for the given audio bytes."""
