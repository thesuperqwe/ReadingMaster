from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ECDICT = Path.home() / "AppData" / "Local" / "Temp" / "ecdict.csv"
DEFAULT_BASE = ROOT / "scripts" / "offline_dictionary_seed.json"
DEFAULT_OUTPUT = ROOT / "apps" / "mobile" / "assets" / "offline_dictionary.json"

CORE_TAGS = {"zk", "gk"}
MAX_FREQUENCY_RANK = 3000


def normalized_word(word: str) -> str:
    return "".join(char for char in word if char.isalnum() or char == "'").lower()


def clean_multiline(value: str | None, max_lines: int = 2) -> str:
    if not value:
        return ""

    lines = [line.strip() for line in value.splitlines() if line.strip()]
    if not lines:
        return ""

    selected = lines[:max_lines]
    text = "；".join(selected)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def clean_translation(value: str | None) -> str:
    cleaned = clean_multiline(value, max_lines=2)
    cleaned = re.sub(r"^[a-z]+\.\s*", "", cleaned, flags=re.IGNORECASE)
    return cleaned


def clean_definition(value: str | None) -> str:
    cleaned = clean_multiline(value, max_lines=1)
    if len(cleaned) > 240:
        cleaned = cleaned[:237].rstrip() + "..."
    return cleaned


def lemma_from_exchange(value: str | None) -> str | None:
    if not value:
        return None

    for token in value.split("/"):
        if token.startswith("0:"):
            lemma = token.split(":", 1)[1].strip().lower()
            if lemma and all(char.isalpha() or char == "'" for char in lemma):
                return lemma
    return None


def parse_exchange(value: str | None) -> list[str]:
    if not value:
        return []

    forms: list[str] = []
    for token in value.split("/"):
        if ":" not in token:
            continue
        kind, form = token.split(":", 1)
        if kind not in {"p", "d", "i", "3", "r", "t", "s"}:
            continue
        form = form.strip().lower()
        if form and all(char.isalpha() or char == "'" for char in form):
            forms.append(form)
    return forms


def is_core_word(row: dict[str, str]) -> bool:
    word = normalized_word(row.get("word", ""))
    if not word or len(word) < 2 or any(char.isspace() for char in word):
        return False

    lemma = lemma_from_exchange(row.get("exchange"))
    if lemma and lemma != word:
        return False

    if row.get("oxford") == "1":
        return True

    tags = set((row.get("tag") or "").split())
    if tags & CORE_TAGS:
        return True

    for field in ("frq", "bnc"):
        raw = row.get(field, "")
        if raw.isdigit() and 0 < int(raw) <= MAX_FREQUENCY_RANK:
            return True

    return False


def load_existing(path: Path) -> dict[str, dict[str, object]]:
    if not path.exists():
        return {}

    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    if not isinstance(data, dict):
        return {}

    normalized: dict[str, dict[str, object]] = {}
    for key, value in data.items():
        if not isinstance(value, dict):
            continue
        entry = dict(value)
        if "example" in entry and "example_sentence" not in entry:
            entry["example_sentence"] = entry.get("example", "")
        normalized[str(key).strip().lower()] = entry
    return normalized


def entry_from_row(row: dict[str, str], existing: dict[str, object] | None = None) -> dict[str, object]:
    base = existing if existing is not None else {}
    word = str(base.get("word") or normalized_word(row.get("word", "")))

    entry: dict[str, object] = {"word": word}
    entry["phonetic"] = base.get("phonetic") or (row.get("phonetic") or "").strip()
    entry["meaning_zh"] = base.get("meaning_zh") or clean_translation(row.get("translation"))
    entry["simple_definition"] = base.get("simple_definition") or clean_definition(row.get("definition"))
    entry["example_sentence"] = base.get("example_sentence") or ""
    entry["example_translation"] = base.get("example_translation") or ""

    pos = (row.get("pos") or "").split("/")[0].split(":")[0].strip()
    entry["part_of_speech"] = base.get("part_of_speech") or pos
    return entry


def build_dictionary(
    ecdict_path: Path,
    output_path: Path,
    base_path: Path,
) -> dict[str, dict[str, object]]:
    output = load_existing(base_path)

    with ecdict_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if not is_core_word(row):
                continue

            word = normalized_word(row.get("word", ""))
            output.setdefault(word, entry_from_row(row, output.get(word)))
            lemma = output[word]

            for form in parse_exchange(row.get("exchange")):
                output.setdefault(form, entry_from_row(row, {"word": word}))

    with ecdict_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            word = normalized_word(row.get("word", ""))
            lemma = lemma_from_exchange(row.get("exchange"))
            if not lemma or lemma == word or lemma not in output:
                continue
            output[word] = entry_from_row(row, output[lemma])

    return output


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate the mobile offline dictionary from ECDICT.",
    )
    parser.add_argument("--ecdict", type=Path, default=DEFAULT_ECDICT)
    parser.add_argument("--base", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    dictionary = build_dictionary(args.ecdict, args.output, args.base)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        if args.pretty:
            json.dump(dictionary, handle, ensure_ascii=False, indent=2)
        else:
            json.dump(dictionary, handle, ensure_ascii=False, separators=(",", ":"))

    print(f"wrote {len(dictionary)} entries to {args.output}")


if __name__ == "__main__":
    main()
