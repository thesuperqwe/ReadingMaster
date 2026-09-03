from abc import ABC, abstractmethod


class OcrProviderError(RuntimeError):
    """Raised when an OCR provider cannot recognize an image."""


class OcrProvider(ABC):
    @abstractmethod
    async def recognize(self, images: list[tuple[bytes, str]]) -> str:
        """Return recognized text for the given (image_bytes, mime_type) list."""
