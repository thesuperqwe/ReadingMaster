from app.asr.base import AsrProvider
from app.asr.siliconflow_provider import SiliconFlowAsrProvider
from app.core.config import get_settings


def get_asr_provider() -> AsrProvider:
    settings = get_settings()
    provider_name = settings.asr_provider.strip().lower()

    if provider_name == "siliconflow":
        return SiliconFlowAsrProvider(
            api_key=settings.asr_api_key,
            base_url=settings.asr_base_url,
            model=settings.asr_model,
        )

    raise ValueError(f"Unsupported ASR provider: {settings.asr_provider}")
