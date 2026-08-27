from app.ai.base import AIProvider
from app.ai.deepseek_provider import DeepSeekProvider
from app.ai.mock_provider import MockProvider
from app.ai.openai_provider import OpenAIProvider
from app.core.config import get_settings


def get_ai_provider() -> AIProvider:
    settings = get_settings()
    provider_name = settings.ai_provider.strip().lower()

    if provider_name == "mock":
        return MockProvider()

    if provider_name == "openai":
        return OpenAIProvider(
            api_key=settings.openai_api_key,
            base_url=settings.openai_base_url,
            model=settings.openai_model,
        )

    if provider_name == "deepseek":
        return DeepSeekProvider(
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
            model=settings.deepseek_model,
        )

    raise ValueError(f"Unsupported AI provider: {settings.ai_provider}")
