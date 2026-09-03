import asyncio
from io import BytesIO

from PIL import Image

from app.ocr.google_provider import GoogleOcrProvider
from app.ocr.image_utils import prepare_pages
from app.ocr.siliconflow_provider import clean_ocr_text


def _jpeg(size, color="white"):
    img = Image.new("RGB", size, color)
    out = BytesIO()
    img.save(out, format="JPEG")
    return out.getvalue()


def test_prepare_pages_splits_landscape_spread():
    pages = prepare_pages(_jpeg((2000, 1200)), "image/jpeg", max_side=1600)
    assert len(pages) == 2
    first = Image.open(BytesIO(pages[0][0]))
    assert first.size[1] > first.size[0]  # each page becomes portrait


def test_prepare_pages_keeps_single_portrait_page():
    pages = prepare_pages(_jpeg((1200, 2000)), "image/jpeg")
    assert len(pages) == 1


def test_clean_ocr_text_removes_page_numbers_and_duplicates():
    text = "006\n\nThe dog is cute.\n\nThe dog is cute.\n\n007\n"
    assert clean_ocr_text(text) == "The dog is cute."


def test_google_recognize_concatenates_pages(monkeypatch):
    provider = GoogleOcrProvider(api_key="key", max_side=99999)

    async def fake_annotate(pages):
        assert len(pages) == 1
        return ["Page A text.", "Page B text."]

    monkeypatch.setattr(provider, "_annotate", fake_annotate)
    result = asyncio.run(provider.recognize([(b"x", "image/jpeg")]))
    assert result == "Page A text.\n\nPage B text."