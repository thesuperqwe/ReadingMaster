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

    async def extract_key_items(self, text: str) -> list[dict[str, Any]]:
        stopwords = {
            "a", "an", "the", "and", "but", "or", "so", "if", "then", "than",
            "that", "this", "these", "those", "he", "she", "it", "they", "we",
            "i", "you", "me", "him", "her", "us", "them", "my", "your", "his",
            "its", "our", "their", "is", "am", "are", "was", "were", "be",
            "been", "being", "have", "has", "had", "do", "does", "did", "will",
            "would", "can", "could", "shall", "should", "may", "might", "must",
            "to", "of", "in", "on", "at", "for", "with", "by", "from", "up",
            "down", "out", "into", "over", "under", "again", "there", "here",
            "not", "no", "yes", "very", "too", "just", "also", "all", "some",
            "any", "many", "much", "more", "most", "one", "two", "three",
            "four", "five", "six", "seven", "eight", "nine", "ten", "about",
            "after", "before", "between", "through", "during", "without",
            "because", "while",
        }
        words = []
        for token in text.split():
            word = token.strip().strip(".,!?;:\"'").lower()
            if word and word not in stopwords and word not in words:
                words.append(word)
        if not words:
            words = ["story"]
        terms = words[:5]
        return [
            {
                "term": term,
                "phonetic": f"/{term}/",
                "meaning_zh": "（示例释义）",
                "simple_definition": "an important word in the story",
            }
            for term in terms
        ]

    async def judge_answer(
        self,
        question: str,
        student_answer: str,
        reference_answer: str | None = None,
        context: str | None = None,
    ) -> dict[str, Any]:
        student = " ".join(student_answer.strip().lower().split())
        if not student:
            return {
                "correct": False,
                "feedback": "我还没有听到答案，再试一次吧。",
                "model_answer": reference_answer or "",
            }

        if not reference_answer:
            return {
                "correct": True,
                "feedback": "已收到你的回答。",
                "model_answer": "",
            }

        def words(value: str) -> set[str]:
            return {
                token.strip().strip(".,!?;:\"'")
                for token in value.lower().split()
                if token.strip()
            }

        reference_words = words(reference_answer)
        if not reference_words:
            return {
                "correct": True,
                "feedback": "已收到你的回答。",
                "model_answer": reference_answer,
            }

        overlap = len(reference_words & words(student)) / len(reference_words)
        correct = overlap >= 0.5
        return {
            "correct": correct,
            "feedback": (
                "答对了！关键意思说到了。"
                if correct
                else "还差一点，再看看原文，试着把关键意思说出来。"
            ),
            "model_answer": reference_answer,
        }