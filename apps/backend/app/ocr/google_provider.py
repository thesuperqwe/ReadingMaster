"""Google Cloud Vision OCR provider.

Cloud Vision's ``DOCUMENT_TEXT_DETECTION`` is deterministic and purpose-built
for printed book text, making it a much better fit than a generic chat/vision
model for photographing physical books. Up to 16 page images are sent per
batched request; each page is mapped back to its own ``fullTextAnnotation``.
"""

import asyncio
import base64
from typing import Any

import httpx2

from app.ocr.base import OcrProvider, OcrProviderError
from app.ocr.image_utils import DEFAULT_MAX_SIDE, prepare_pages

BATCH_SIZE = 16


def _extract_page_text(response: dict[str, Any]) -> str:
    annotation = response.get("fullTextAnnotation") or {}
    return (annotation.get("text") or "").strip()


class GoogleOcrProvider(OcrProvider):
    def __init__(
        self,
        api_key: str | None,
        *,
        max_side: int = DEFAULT_MAX_SIDE,
        retries: int = 3,
    ) -> None:
        self.api_key = api_key
        self.max_side = max_side
        self.retries = max(1, retries)

    async def recognize(self, images: list[tuple[bytes, str]]) -> str:
        if not self.api_key:
            raise OcrProviderError("Google OCR API key is not configured")

        pages: list[tuple[bytes, str]] = []
        for image, mime_type in images:
            pages.extend(prepare_pages(image, mime_type, max_side=self.max_side))

        texts: list[str] = []
        for offset in range(0, len(pages), BATCH_SIZE):
            batch = pages[offset : offset + BATCH_SIZE]
            for text in await self._annotate(batch):
                if text:
                    texts.append(text)

        result = "\n\n".join(texts)
        if not result.strip():
            raise OcrProviderError("OCR returned no text")
        return result.strip()

    async def _annotate(
        self, pages: list[tuple[bytes, str]]
    ) -> list[str]:
        requests = [
            {
                "image": {"content": base64.b64encode(data).decode()},
                "features": [{"type": "DOCUMENT_TEXT_DETECTION"}],
            }
            for data, _mime in pages
        ]
        payload = {"requests": requests}
        url = f"https://vision.googleapis.com/v1/images:annotate?key={self.api_key}"

        last_error: Exception | None = None
        for attempt in range(self.retries):
            try:
                async with httpx2.AsyncClient(timeout=180) as client:
                    response = await client.post(url, json=payload)
                    response.raise_for_status()
                    data = response.json()
                responses = data.get("responses", [])
                return [_extract_page_text(resp) for resp in responses]
            except httpx2.HTTPError as exc:
                last_error = exc
                if attempt + 1 < self.retries:
                    await asyncio.sleep(2 * (attempt + 1))

        raise OcrProviderError(f"Google OCR request failed: {last_error}")