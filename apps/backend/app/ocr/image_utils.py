"""Image preprocessing helpers for OCR providers.

Photos captured from a tablet/phone arrive as raw bytes, often as HEIC (iPhone /
iPad default), and frequently with an EXIF orientation tag or as a portrait
frame around a landscape book spread. Feeding those bytes directly to a vision
model degrades recognition. These helpers normalize orientation, split a
two-page spread into its constituent pages, downscale to a sane size, and mildly
enhance contrast so the OCR model sees clean, upright text.
"""

from io import BytesIO

from PIL import Image, ImageEnhance, ImageOps

# iPad / iPhone default camera format. Optional dependency: when unavailable we
# simply fall back to sending the original bytes rather than failing.
try:
    from pillow_heif import register_heif_opener

    register_heif_opener()
except Exception:  # pragma: no cover - optional dependency
    pass

DEFAULT_MAX_SIDE = 1600
DEFAULT_JPEG_QUALITY = 90

# Aspect ratio at or above which a landscape photo is treated as a two-page
# book spread and split into left/right pages. A single photographed page is
# usually portrait, so this threshold avoids cheating a tilted single page.
SPREAD_MIN_ASPECT = 1.25


def split_spread_pages(
    image: Image.Image, min_aspect: float = SPREAD_MIN_ASPECT
) -> list[Image.Image]:
    """Split a landscape book-spread photo into its two pages.

    Returns a 1-element list for a single page (or a simply wide, non-spread
    image). For a spread the outer book edges and the center gutter are cropped
    away so each page is fed to OCR on its own, which is far more reliable than
    sending a full spread to a vision model.
    """
    width, height = image.size
    if width / height < min_aspect:
        return [image]

    left = image.crop((int(0.06 * width), 0, int(0.48 * width), height))
    right = image.crop((int(0.52 * width), 0, int(0.97 * width), height))
    return [left, right]


def _prepare_page(image: Image.Image, max_side: int, jpeg_quality: int) -> bytes:
    """Normalize and re-encode a single page image as JPEG."""
    if max_side > 0 and max(image.size) > max_side:
        image.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)

    image = ImageOps.autocontrast(image, cutoff=1)
    image = ImageEnhance.Contrast(image).enhance(1.1)

    out = BytesIO()
    image.save(out, format="JPEG", quality=jpeg_quality, optimize=True)
    return out.getvalue()


def prepare_pages(
    raw: bytes,
    mime_type: str,
    *,
    max_side: int = DEFAULT_MAX_SIDE,
    jpeg_quality: int = DEFAULT_JPEG_QUALITY,
) -> list[tuple[bytes, str]]:
    """Return a list of (processed_bytes, mime_type) page images for OCR.

    Decodes the input (handling HEIC), normalizes EXIF orientation, splits a
    two-page spread, then re-encodes each page as a compact JPEG. If the image
    cannot be decoded, the original bytes are returned as a single item so
    recognition can still proceed rather than failing outright.
    """
    try:
        image = Image.open(BytesIO(raw))
        image = ImageOps.exif_transpose(image)
        image = image.convert("RGB")
    except Exception:
        return [(raw, mime_type)]

    pages = split_spread_pages(image)
    prepared: list[tuple[bytes, str]] = []
    for page in pages:
        prepared.append(
            (_prepare_page(page, max_side, jpeg_quality), "image/jpeg")
        )
    return prepared


def preprocess_image(
    raw: bytes,
    mime_type: str,
    *,
    max_side: int = DEFAULT_MAX_SIDE,
    jpeg_quality: int = DEFAULT_JPEG_QUALITY,
) -> tuple[bytes, str]:
    """Return (processed_bytes, mime_type) for a single OCR image.

    Normalizes EXIF orientation, downscales, and re-encodes as JPEG without
    splitting a spread. Use :func:`prepare_pages` when a photo may contain two
    book pages so the spread is split before recognition.
    """
    try:
        image = Image.open(BytesIO(raw))
        image = ImageOps.exif_transpose(image)
        image = image.convert("RGB")
    except Exception:
        return raw, mime_type
    return _prepare_page(image, max_side, jpeg_quality), "image/jpeg"
