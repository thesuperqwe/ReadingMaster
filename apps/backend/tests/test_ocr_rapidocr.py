import asyncio
from io import BytesIO

from PIL import Image

from app.ocr.rapidocr_provider import (
    RapidOcrProvider,
    _best_words_split,
    _repair_concatenated_words,
)
from app.ocr.siliconflow_provider import clean_ocr_text


def _jpeg(size, color="white"):
    img = Image.new("RGB", size, color)
    out = BytesIO()
    img.save(out, format="JPEG")
    return out.getvalue()


def test_clean_ocr_text_removes_running_headers_and_page_numbers():
    text = "Chapter 2\nsmall person.\nChapter2\nsmall person.\n007\n"
    assert clean_ocr_text(text) == "Chapter 2\nsmall person."


def test_rapidocr_provider_concatenates_split_pages(monkeypatch):
    import app.ocr.rapidocr_provider as rapidocr_module

    def fake_recognize_page_scored(engine, page):
        return "The dog is cute.", 1.0

    monkeypatch.setattr(
        RapidOcrProvider,
        "_recognize_page_scored",
        staticmethod(fake_recognize_page_scored),
    )
    monkeypatch.setattr(rapidocr_module, "_get_engine", lambda: object())

    provider = RapidOcrProvider()
    result = asyncio.run(provider.recognize([(_jpeg((2000, 1200)), "image/jpeg")]))
    assert result == "The dog is cute."


def test_best_words_split_concatenation():
    wordset = {
        "his", "pocket", "out", "of", "the", "little", "prince", "was",
        "revealed", "from", "sky", "that", "would",
    }
    assert _best_words_split("hispocket", wordset) == ["his", "pocket"]
    assert _best_words_split("outof", wordset) == ["out", "of"]
    assert _best_words_split("TheLittlePrince", wordset) == ["the", "little", "prince"]
    assert _best_words_split("fromthesky", wordset) == ["from", "the", "sky"]
    # Already-a-word tokens are left whole.
    assert _best_words_split("pocket", wordset) is None


def test_repair_concatenated_words_preserves_capitalization():
    text = _repair_concatenated_words("TheLittlePrince wasrevealed tome. Ianswered.")
    assert "Little Prince" in text
    assert "was revealed" in text
    assert "I answered" in text

def _box(x0, y0, x1, y1):
    return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]


def test_reorder_scores_upright_text_over_sideways():
    from app.ocr.rapidocr_provider import _reorder_detections

    def detected(box_width, box_height):
        dets = []
        for i, y in enumerate([100, 200, 300]):
            dets.append([_box(250, y, 250 + box_width, y + box_height), f"word{i}", 0.9])
        return dets

    # Upright text yields wide, short boxes; a 90-degree rotation yields tall,
    # narrow boxes with the same confidence. The orientation score must prefer
    # the upright arrangement so a rotated page is never selected.
    _, upright_score = _reorder_detections(detected(100, 20), 1000, 1000)
    _, sideways_score = _reorder_detections(detected(20, 100), 1000, 1000)
    assert upright_score > sideways_score
    assert sideways_score == 0.0