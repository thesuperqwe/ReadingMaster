from app.core.config import get_settings
from app.ocr.base import OcrProvider
from app.ocr.google_provider import GoogleOcrProvider
from app.ocr.rapidocr_provider import RapidOcrProvider
from app.ocr.siliconflow_provider import SiliconFlowOcrProvider


def get_ocr_provider() -> OcrProvider:
    settings = get_settings()
    provider_name = settings.ocr_provider.strip().lower()

    if provider_name == "siliconflow":
        return SiliconFlowOcrProvider(
            api_key=settings.ocr_api_key or settings.asr_api_key,
            base_url=settings.ocr_base_url or settings.asr_base_url,
            model=settings.ocr_model,
            prompt=settings.ocr_prompt,
            max_side=settings.ocr_max_side,
            retries=settings.ocr_retries,
        )

    if provider_name == "google":
        return GoogleOcrProvider(
            api_key=settings.google_ocr_api_key or settings.google_tts_api_key,
            max_side=settings.ocr_max_side,
            retries=settings.ocr_retries,
        )

    if provider_name == "rapidocr":
        return RapidOcrProvider()

    raise ValueError(f"Unsupported OCR provider: {settings.ocr_provider}")
