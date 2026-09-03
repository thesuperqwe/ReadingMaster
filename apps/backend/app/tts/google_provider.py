import base64
from typing import Any

import httpx2

from app.tts.base import TtsProvider, TtsProviderError


class GoogleTtsProvider(TtsProvider):
    def __init__(
        self,
        api_key: str | None,
        access_token: str | None = None,
        voice: str = "en-US-Neural2-C",
        speaking_rate: float = 0.85,
        pitch: float = 0.0,
    ) -> None:
        self.api_key = api_key
        self.access_token = access_token
        self.voice = voice
        self.speaking_rate = speaking_rate
        self.pitch = pitch

    @property
    def _is_journey(self) -> bool:
        return "-Journey-" in self.voice

    async def synthesize(self, text: str, language_code: str = "en-US") -> tuple[bytes, str]:
        if not self.access_token and not self.api_key:
            raise TtsProviderError("Google TTS credentials are not configured")

        normalized_text = " ".join(text.split())

        if self._is_journey:
            audio_config: dict[str, Any] = {"audioEncoding": "LINEAR16"}
            mime_type = "audio/wav"
        else:
            audio_config = {
                "audioEncoding": "MP3",
                "speakingRate": self.speaking_rate,
                "pitch": self.pitch,
            }
            mime_type = "audio/mpeg"

        url = "https://texttospeech.googleapis.com/v1/text:synthesize"
        headers = {
            "Content-Type": "application/json; charset=utf-8",
        }
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        else:
            headers["X-Goog-Api-Key"] = self.api_key

        payload: dict[str, Any] = {
            "input": {"text": normalized_text},
            "voice": {
                "languageCode": language_code,
                "name": self.voice,
            },
            "audioConfig": audio_config,
        }

        try:
            async with httpx2.AsyncClient(timeout=30) as client:
                response = await client.post(url, headers=headers, json=payload)
                response.raise_for_status()
                data = response.json()
        except httpx2.HTTPError as exc:
            raise TtsProviderError(f"Google TTS request failed: {exc}") from exc

        audio_content = data.get("audioContent")
        if not isinstance(audio_content, str) or not audio_content:
            raise TtsProviderError("Google TTS returned no audio content")

        return base64.b64decode(audio_content), mime_type