"""SiliconFlow vision-model backed OCR provider.

Recognition is done one *page* at a time. A photo of a two-page book spread is
split by :func:`app.ocr.image_utils.split_spread_pages`, and each page is sent
to the model in its own request. Sending a single page per request is far more
reliable than feeding a full spread (or several images in one payload) to the
underlying vision model.
"""

import asyncio
import base64
import re
from typing import Any

import httpx2

from app.ocr.base import OcrProvider, OcrProviderError
from app.ocr.image_utils import DEFAULT_MAX_SIDE, prepare_pages

# Hard constraints that bias the model toward verbatim transcription rather than
# paraphrasing or captioning, which DeepSeek-OCR otherwise tends to do on
# illustration-heavy pages.
DEFAULT_OCR_PROMPT = (
    "You are an OCR engine. Reproduce the book page text EXACTLY, word for "
    "word, in the order it appears on the page. Do NOT summarize, do NOT "
    "paraphrase, do NOT describe, do NOT explain, and do NOT add commentary, "
    "captions, or metadata. If the page is mostly an illustration with a "
    "caption, output only the caption text. If the page has a full-page "
    "picture with no body text, leave it blank. Ignore page numbers, headers, "
    "footers, and the illustration itself. The photo may be taken sideways or "
    "at an angle; read it as an upright page. Use plain English text only."
)

PAGE_NUMBER_RE = re.compile(r"^\s*\d{3,}\s*$")
RUNNING_HEADER_RE = re.compile(r"^\s*(?:chapter|part)\d+\s*$", re.IGNORECASE)


def clean_ocr_text(text: str) -> str:
    """Strip common OCR artifacts: page numbers and duplicated lines.

    Keeps the core transcription intact while removing the noise that a vision
    model routinely inserts around book photographs.
    """
    lines = text.replace("\r\n", "\n").split("\n")
    cleaned: list[str] = []
    prev: str | None = None
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if PAGE_NUMBER_RE.match(line) or RUNNING_HEADER_RE.match(line):
            continue
        if line == prev:
            continue
        cleaned.append(line)
        prev = line
    return "\n".join(cleaned)


def _extract_text(data: Any) -> str:
    try:
        message = data["choices"][0]["message"]
    except (KeyError, IndexError, TypeError):
        return ""

    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
        return "\n".join(parts)
    return ""


class SiliconFlowOcrProvider(OcrProvider):
    def __init__(
        self,
        api_key: str | None,
        base_url: str,
        model: str,
        *,
        prompt: str | None = None,
        max_side: int = DEFAULT_MAX_SIDE,
        retries: int = 3,
    ) -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.prompt = prompt if (prompt and prompt.strip()) else DEFAULT_OCR_PROMPT
        self.max_side = max_side
        self.retries = max(1, retries)

    async def recognize(self, images: list[tuple[bytes, str]]) -> str:
        if not self.api_key:
            raise OcrProviderError("OCR API key is not configured")

        chunks: list[str] = []
        for image, mime_type in images:
            for page_bytes, page_mime in prepare_pages(
                image, mime_type, max_side=self.max_side
            ):
                page_text = await self._recognize_page(page_bytes, page_mime)
                chunk = clean_ocr_text(page_text)
                if chunk:
                    chunks.append(chunk)

        text = "\n\n".join(chunks)
        if not text.strip():
            raise OcrProviderError("OCR returned no text")
        return text.strip()

    async def _recognize_page(self, image: bytes, mime_type: str) -> str:
        content: list[dict[str, Any]] = []
        if self.prompt:
            content.append({"type": "text", "text": self.prompt})
        content.append(
            {
                "type": "image_url",
                "image_url": {
                    "url": (
                        f"data:{mime_type};base64,"
                        f"{base64.b64encode(image).decode()}"
                    )
                },
            }
        )

        payload = {
            "model": self.model,
            "messages": [{"role": "user", "content": content}],
        }
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        last_error: Exception | None = None
        for attempt in range(self.retries):
            try:
                async with httpx2.AsyncClient(timeout=180) as client:
                    response = await client.post(
                        f"{self.base_url}/chat/completions",
                        headers=headers,
                        json=payload,
                    )
                    response.raise_for_status()
                    data = response.json()
                return _extract_text(data)
            except httpx2.HTTPError as exc:
                last_error = exc
                if attempt + 1 < self.retries:
                    await asyncio.sleep(2 * (attempt + 1))

        raise OcrProviderError(f"OCR request failed: {last_error}")
