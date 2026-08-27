from app.ai.openai_provider import OpenAICompatibleProvider


class DeepSeekProvider(OpenAICompatibleProvider):
    def __init__(self, api_key: str | None, base_url: str, model: str) -> None:
        super().__init__(api_key, base_url, model)
