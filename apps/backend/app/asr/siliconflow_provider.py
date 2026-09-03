from typing import Any

import httpx2

from app.asr.base import AsrProvider, AsrProviderError


class SiliconFlowAsrProvider(AsrProvider):
    def __init__(self, api_key: str | None, base_url: str, model: str) -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model

    async def transcribe(self, audio: bytes, mime_type: str) -> str:
        if not self.api_key:
            raise AsrProviderError("ASR API key is not configured")

        url = f"{self.base_url}/audio/transcriptions"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        files = {"file": ("audio.bin", audio, mime_type)}
        data: dict[str, Any] = {"model": self.model}

        try:
            async with httpx2.AsyncClient(timeout=60) as client:
                response = await client.post(
                    url, headers=headers, files=files, data=data
                )
                response.raise_for_status()
                payload = response.json()
        except httpx2.HTTPError as exc:
            raise AsrProviderError(f"ASR request failed: {exc}") from exc

        text = payload.get("text")
        if not isinstance(text, str) or not text.strip():
            raise AsrProviderError("ASR returned no transcript")

        return text.strip()
