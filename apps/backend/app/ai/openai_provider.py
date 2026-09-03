from typing import Any

import httpx2

from app.ai.base import AIProvider, AIProviderError, extract_json


class OpenAICompatibleProvider(AIProvider):
    def __init__(self, api_key: str | None, base_url: str, model: str) -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model

    async def _chat_json(self, system_prompt: str, user_prompt: str) -> Any:
        if not self.api_key:
            raise AIProviderError("AI API key is not configured")

        url = f"{self.base_url}/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
        }

        async with httpx2.AsyncClient(timeout=30) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()

        content = data["choices"][0]["message"]["content"]
        return extract_json(content)

    async def explain_word(self, word: str, context: str | None = None) -> dict[str, str | None]:
        system_prompt = (
            "You are an English teacher for a Chinese Grade 3 student. "
            "Return JSON only with fields: word, phonetic, meaning_zh, "
            "simple_definition, example, example_translation."
        )
        user_prompt = f"Word: {word}\nContext: {context or 'No context'}"
        return await self._chat_json(system_prompt, user_prompt)

    async def generate_quiz(self, text: str) -> list[dict[str, Any]]:
        system_prompt = (
            "Create exactly three single-choice reading comprehension questions for a child. "
            "Return JSON only as {\"questions\": [{\"question\": \"...\", "
            "\"correct_option\": \"A\", \"options\": [{\"option_key\": \"A\", "
            "\"content\": \"...\"}]}]} with exactly three items."
        )
        user_prompt = f"Story text:\n{text}"
        data = await self._chat_json(system_prompt, user_prompt)
        questions = data.get("questions", data) if isinstance(data, dict) else data
        if not isinstance(questions, list):
            raise AIProviderError("Invalid generate_quiz response")
        return questions

    async def extract_key_items(self, text: str) -> list[dict[str, Any]]:
        system_prompt = (
            "Identify 3 to 6 important words or short phrases in the text for a Chinese "
            "Grade 3 English learner. Exclude common function words and sight words such as "
            "a, an, the, is, are, and, to, of, he, she, it. Prefer content words and meaningful "
            "collocations. Each term must appear in the text. Return JSON only as "
            "{\"items\": [{\"term\": \"...\", \"phonetic\": \"...\", \"meaning_zh\": \"...\", \"simple_definition\": \"...\"}]}."
        )
        user_prompt = f"Text:\n{text}"
        data = await self._chat_json(system_prompt, user_prompt)
        items = data.get("items", data) if isinstance(data, dict) else data
        if not isinstance(items, list):
            raise AIProviderError("Invalid key-items response")
        return items

    async def judge_answer(
        self,
        question: str,
        student_answer: str,
        reference_answer: str | None = None,
        context: str | None = None,
    ) -> dict[str, Any]:
        system_prompt = (
            "You are an English reading teacher for a Chinese Grade 3 student. "
            "Judge whether the child's spoken answer matches the question. "
            "Accept small grammar mistakes as long as the key meaning is correct. "
            "Return JSON only with fields: correct (boolean), feedback (short Chinese feedback), "
            "model_answer (a child-friendly English model answer)."
        )
        user_prompt = (
            f"Question: {question}\n"
            f"Reference answer: {reference_answer or 'None'}\n"
            f"Student answer: {student_answer}\n"
            f"Context: {context or 'None'}"
        )
        data = await self._chat_json(system_prompt, user_prompt)
        return {
            "correct": bool(data.get("correct")),
            "feedback": str(data.get("feedback") or ""),
            "model_answer": str(data.get("model_answer") or ""),
        }


class OpenAIProvider(OpenAICompatibleProvider):
    def __init__(self, api_key: str | None, base_url: str, model: str) -> None:
        super().__init__(api_key, base_url, model)
