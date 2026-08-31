import json
import re
from abc import ABC, abstractmethod
from typing import Any


class AIProviderError(RuntimeError):
    pass


def extract_json(text: str) -> Any:
    text = text.strip()

    fence = re.match(r"^```(?:json)?\s*\n?(.*?)\n?```$", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    for pattern in (r"\{.*\}", r"\[.*\]"):
        match = re.search(pattern, text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass

    snippet = text[:200].replace("\n", " ")
    raise AIProviderError(f"AI response did not contain valid JSON: {snippet!r}")


class AIProvider(ABC):
    @abstractmethod
    async def explain_word(self, word: str, context: str | None = None) -> dict[str, str | None]:
        raise NotImplementedError

    @abstractmethod
    async def generate_quiz(self, text: str) -> list[dict[str, Any]]:
        raise NotImplementedError
