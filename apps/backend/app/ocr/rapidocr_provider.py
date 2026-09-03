"""Local RapidOCR provider.

RapidOCR runs PaddleOCR's PP-OCRv4 models on CPU through ONNX Runtime. It is
offline, free, deterministic, and bundles its models with the package, so it
avoids the per-call cost and instability of a generic vision API. It is the
recommended backend for photographing physical book pages.

Photo handling is tailored to real book photos: the image is auto-oriented
(0/90/180/270), a two-page spread is split at the gutter, detection boxes are
re-ordered into natural reading order, page-edge bleed from the neighbouring
page is dropped, and concatenated words (a common artifact of tight book
typesetting / wrong orientation) are re-split using a bundled English wordlist.
"""

from __future__ import annotations

import asyncio
import io
import re
import threading
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageOps

from app.ocr.base import OcrProvider, OcrProviderError
from app.ocr.image_utils import split_spread_pages
from app.ocr.siliconflow_provider import clean_ocr_text

_engine: Any | None = None
_engine_lock = threading.Lock()
_wordset: set[str] | None = None
_wordset_lock = threading.Lock()
_WORDLIST = Path(__file__).with_name("wordlist.txt")

# Adjacent-page bleed produces a narrow column of word fragments along the
# outer edge of a photographed page. Those boxes survive detection but belong to
# the neighbouring page, so they are dropped before reading order is rebuilt.
EDGE_FRACTION = 0.12
NARROW_FRACTION = 0.30
MIN_BOX_SIDE = 8

# Downscale very large phone photos before recognition: this keeps CPU time
# bounded without hurting accuracy on a book page.
MAX_SIDE = 1600

# Orientation candidates. Book pages photographed with a phone/tablet are most
# often upright or flipped 180 degrees, but 90/270 cover a camera held sideways.
ROTATIONS = (0, 90, 180, 270)

_WORD_TOKEN_RE = re.compile(r"[A-Za-z']+")
_SINGLE_CHAR_WORDS = {"a", "i"}


def _get_wordset() -> set[str]:
    global _wordset
    with _wordset_lock:
        if _wordset is None:
            _wordset = set(_WORDLIST.read_text(encoding="utf-8").splitlines())
    return _wordset


def _line_center(line: list[tuple[float, float, float, float, str]]) -> float:
    return sum((item[1] + item[2]) / 2 for item in line) / len(line)


def _reorder_detections(
    detected: Any, page_width: int, page_height: int
) -> tuple[list[str], float]:
    """Rebuild natural reading order from RapidOCR detection boxes.

    Returns ``(lines, total_confidence)``. RapidOCR returns boxes in detection
    order, which interleaves a narrow strip of the adjacent page with the real
    body text. This groups boxes into lines by vertical overlap, sorts
    top-to-bottom then left-to-right, discards narrow edge-hugging boxes (page
    bleed) plus near-empty detections, and accumulates the surviving confidence
    so callers can compare orientation candidates.
    """
    items: list[tuple[float, float, float, float, str]] = []
    score = 0.0
    wide_count = 0
    for entry in detected:
        if len(entry) < 2 or not entry[1]:
            continue
        box = entry[0]
        xs = [float(point[0]) for point in box]
        ys = [float(point[1]) for point in box]
        x0, x1 = min(xs), max(xs)
        y0, y1 = min(ys), max(ys)
        width = x1 - x0
        height = y1 - y0
        if width < MIN_BOX_SIDE or height < MIN_BOX_SIDE:
            continue

        if width > height:
            wide_count += 1

        x_center = (x0 + x1) / 2
        is_edge_strip = (
            (x_center < page_width * EDGE_FRACTION)
            or (x_center > page_width * (1 - EDGE_FRACTION))
        ) and width < page_width * NARROW_FRACTION
        if is_edge_strip:
            continue

        try:
            score += float(entry[2])
        except (IndexError, TypeError, ValueError):
            pass
        items.append((x_center, y0, y1, x0, str(entry[1]).strip()))

    if not items:
        return [], 0.0

    items.sort(key=lambda item: ((item[1] + item[2]) / 2, item[3]))

    lines: list[list[tuple[float, float, float, float, str]]] = []
    y_tolerance = max(20, page_height * 0.02)
    for item in items:
        y_center = (item[1] + item[2]) / 2
        if lines and abs(y_center - _line_center(lines[-1])) < y_tolerance:
            lines[-1].append(item)
        else:
            lines.append([item])

    output: list[str] = []
    for line in lines:
        line.sort(key=lambda item: item[3])
        output.append(" ".join(item[4] for item in line if item[4]))
    wide_ratio = wide_count / len(items) if items else 0.0
    return [line for line in output if line], score * wide_ratio


def _best_words_split(token: str, wordset: set[str]) -> list[str] | None:
    """Split a concatenated token into dictionary words, or ``None``.

    Returns the fewest-piece segmentation of ``token`` when it is not itself a
    dictionary word but can be split entirely into dictionary words with at
    least two pieces. Single-letter pieces are only accepted for ``a`` / ``i``
    to avoid over-splitting.
    """
    lower = token.lower()
    if lower in wordset:
        return None
    n = len(lower)
    if n < 2:
        return None

    best: list[list[str] | None] = [None] * (n + 1)
    best[0] = []
    for start in range(n):
        if best[start] is None:
            continue
        for end in range(start + 1, n + 1):
            part = lower[start:end]
            if len(part) == 1 and part not in _SINGLE_CHAR_WORDS:
                continue
            if part not in wordset:
                continue
            candidate = best[start] + [part]
            if best[end] is None or len(candidate) < len(best[end]):
                best[end] = candidate

    pieces = best[n]
    if pieces is None or len(pieces) < 2:
        return None
    return pieces


def _repair_concatenated_words(text: str) -> str:
    """Re-split OCR tokens that lost their spaces (``hispocket`` -> ``his pocket``)."""
    wordset = _get_wordset()

    def _repl(match: re.Match[str]) -> str:
        token = match.group(0)
        pieces = _best_words_split(token, wordset)
        if pieces is None:
            return token
        internal_caps = any(ch.isupper() for ch in token[1:])
        if internal_caps:
            return " ".join(piece[0].upper() + piece[1:] for piece in pieces)
        if token[:1].isupper():
            pieces[0] = pieces[0][0].upper() + pieces[0][1:]
        return " ".join(pieces)

    return _WORD_TOKEN_RE.sub(_repl, text)


def _get_engine() -> Any:
    global _engine
    with _engine_lock:
        if _engine is None:
            from rapidocr_onnxruntime import RapidOCR

            _engine = RapidOCR()
    return _engine


def _decode_image(raw: bytes) -> Image.Image | None:
    try:
        image = Image.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image)
        image = image.convert("RGB")
    except Exception:
        return None
    if MAX_SIDE > 0 and max(image.size) > MAX_SIDE:
        image.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
    return image


class RapidOcrProvider(OcrProvider):
    async def recognize(self, images: list[tuple[bytes, str]]) -> str:
        # RapidOCR is CPU-bound; run it in a worker thread so the async event
        # loop keeps serving other requests during recognition.
        return await asyncio.to_thread(self._recognize_sync, images)

    def _recognize_sync(self, images: list[tuple[bytes, str]]) -> str:
        engine = _get_engine()
        pages: list[str] = []

        for raw, _mime_type in images:
            image = _decode_image(raw)
            if image is None:
                continue
            text = self._recognize_best_orientation(engine, image)
            if text:
                pages.append(text)

        # Do NOT auto-split concatenated tokens. The bundled wordlist is sparse on
        # inflected forms (habitation, straying), so splitting real words into
        # dictionary fragments measurably lowers accuracy on clean pages; genuine
        # run-together words on degraded photos are misread at the letter level and
        # cannot be recovered this way anyway. Keep the helpers for explicit use.
        result = clean_ocr_text("\n\n".join(pages)).strip()
        if not result:
            raise OcrProviderError("OCR returned no text")
        return result

    @staticmethod
    def _recognize_best_orientation(engine: Any, image: Image.Image) -> str:
        """Recognize ``image`` after trying every rotation.

        The rotation that produces the most confident text (sum of surviving
        detection confidence) wins. The spread/single-page split is computed on
        the original orientation, then each resulting page is rotated so a
        sideways single page is never mistaken for a two-page spread.
        """
        base_pages = split_spread_pages(image)
        best_text = ""
        best_score = -1.0
        for angle in ROTATIONS:
            parts: list[str] = []
            score = 0.0
            for page in base_pages:
                rotated = page.rotate(angle, expand=True) if angle else page
                text, page_score = RapidOcrProvider._recognize_page_scored(
                    engine, rotated
                )
                score += page_score
                if text:
                    parts.append(text)
            if score > best_score:
                best_score = score
                best_text = "\n".join(parts)
        return best_text

    @staticmethod
    def _recognize_page_scored(engine: Any, page: Image.Image) -> tuple[str, float]:
        detected, _elapsed = engine(np.asarray(page))
        if not detected:
            return "", 0.0
        width, height = page.size
        lines, score = _reorder_detections(detected, width, height)
        return "\n".join(lines), score

    @staticmethod
    def _recognize_page(engine: Any, page: Image.Image) -> str:
        text, _score = RapidOcrProvider._recognize_page_scored(engine, page)
        return text