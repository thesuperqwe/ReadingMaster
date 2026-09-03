from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


def _find_env_file() -> Path | None:
    current = Path(__file__).resolve()
    for parent in current.parents:
        candidate = parent / ".env"
        if candidate.exists():
            return candidate
    return None


class Settings(BaseSettings):
    app_name: str = "ReadingMaster API"
    database_url: str = (
        "postgresql+asyncpg://readingmaster:readingmaster_dev@localhost:5432/readingmaster"
    )
    jwt_secret_key: str = "dev-only-change-me-please-use-32-bytes-minimum"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    ai_provider: str = "mock"
    tts_provider: str = "google"

    google_tts_api_key: str | None = None
    google_tts_access_token: str | None = None
    google_tts_voice: str = "en-US-Journey-O"
    google_tts_speaking_rate: float = 0.85
    google_tts_pitch: float = 0.0
    google_ocr_api_key: str | None = None

    asr_provider: str = "siliconflow"
    asr_api_key: str | None = None
    asr_base_url: str = "https://api.siliconflow.cn/v1"
    asr_model: str = "FunAudioLLM/SenseVoiceSmall"

    ocr_provider: str = "siliconflow"
    ocr_api_key: str | None = None
    ocr_base_url: str = "https://api.siliconflow.cn/v1"
    ocr_model: str = "deepseek-ai/DeepSeek-OCR"
    ocr_prompt: str | None = None
    ocr_max_side: int = 1600
    ocr_retries: int = 3

    openai_api_key: str | None = None
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    deepseek_api_key: str | None = None
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-chat"

    model_config = SettingsConfigDict(
        env_file=_find_env_file(),
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
