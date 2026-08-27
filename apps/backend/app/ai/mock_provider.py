import re
from typing import Any

from app.ai.base import AIProvider


class MockProvider(AIProvider):
    async def explain_word(self, word: str, context: str | None = None) -> dict[str, str | None]:
        normalized = word.strip().lower()
        entries = {
            "little": {
                "phonetic": "/ˈlɪtl/",
                "meaning_zh": "小的",
                "simple_definition": "small in size",
                "example": "Tom has a little dog.",
                "example_translation": "汤姆有一只小狗。",
            },
            "dog": {
                "phonetic": "/dɔːɡ/",
                "meaning_zh": "狗",
                "simple_definition": "a friendly animal that people keep as a pet",
                "example": "The dog is very cute.",
                "example_translation": "这只狗非常可爱。",
            },
            "cute": {
                "phonetic": "/kjuːt/",
                "meaning_zh": "可爱的",
                "simple_definition": "nice and lovely",
                "example": "The dog is very cute.",
                "example_translation": "这只狗非常可爱。",
            },
            "play": {
                "phonetic": "/pleɪ/",
                "meaning_zh": "玩",
                "simple_definition": "to do things for fun",
                "example": "Tom likes to play with his dog.",
                "example_translation": "汤姆喜欢和他的狗玩。",
            },
        }

        entry = entries.get(normalized)
        if entry is None:
            return {
                "word": normalized,
                "phonetic": None,
                "meaning_zh": None,
                "simple_definition": None,
                "example": f"This is {normalized}.",
                "example_translation": None,
            }

        return {
            "word": normalized,
            **entry,
        }

    async def generate_quiz(self, text: str) -> list[dict[str, Any]]:
        sentences = [
            sentence.strip()
            for sentence in re.split(r"(?<=[.!?])\s+", text.strip())
            if sentence.strip()
        ]
        if not sentences:
            sentences = ["This is a short story."]

        return [
            {
                "question": "What is this story about?",
                "correct_option": "A",
                "options": [
                    {"option_key": "A", "content": "A short story"},
                    {"option_key": "B", "content": "A long game"},
                    {"option_key": "C", "content": "A school day"},
                ],
            },
            {
                "question": "Which sentence appears in the story?",
                "correct_option": "A",
                "options": [
                    {"option_key": "A", "content": sentences[0]},
                    {"option_key": "B", "content": "The cat is blue."},
                    {"option_key": "C", "content": "School is fun."},
                ],
            },
            {
                "question": "How many reading parts does this story have?",
                "correct_option": "A",
                "options": [
                    {"option_key": "A", "content": str(len(sentences))},
                    {"option_key": "B", "content": str(max(1, len(sentences) + 1))},
                    {"option_key": "C", "content": str(max(1, len(sentences) + 2))},
                ],
            },
        ]
