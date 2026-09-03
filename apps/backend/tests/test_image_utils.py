from io import BytesIO

from PIL import Image

from app.ocr.image_utils import preprocess_image


def _make_jpeg(size, color):
    img = Image.new("RGB", size, color)
    out = BytesIO()
    img.save(out, format="JPEG")
    return out.getvalue()


def test_preprocess_image_downscales_long_side():
    raw = _make_jpeg((1600, 2400), "white")
    data, mime = preprocess_image(raw, "image/jpeg", max_side=1600)
    assert mime == "image/jpeg"
    img = Image.open(BytesIO(data))
    assert max(img.size) <= 1600


def test_preprocess_image_returns_original_for_unsupported_input():
    raw = b"\xff\xd8\xff\xe0" + b"\x00" * 64
    data, mime = preprocess_image(raw, "image/png")
    assert data == raw
    assert mime == "image/png"


def test_preprocess_image_preserves_readable_content():
    raw = _make_jpeg((800, 600), "white")
    data, mime = preprocess_image(raw, "image/jpeg")
    img = Image.open(BytesIO(data))
    assert img.size == (800, 600)


def test_preprocess_image_decodes_heic():
    src = Image.new("RGB", (400, 600), "white")
    buf = BytesIO()
    src.save(buf, format="HEIF")
    raw = buf.getvalue()
    data, mime = preprocess_image(raw, "image/heic")
    assert mime == "image/jpeg"
    img = Image.open(BytesIO(data))
    assert img.size == (400, 600)
