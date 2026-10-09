#!/usr/bin/env python3
"""Writes the expected output of the Arabic folding parity test.

Run from the repository root, after any change to `normalize()` in
`build_hadith_db.py` or to the probe list:

    python3 Tools/CorpusBuilder/export_normalize_parity.py

The hadith index is built by `build_hadith_db.py`'s `normalize()`, and every
hadith query is folded by `Packages/ArabicText`'s `ArabicNormalizer`. A search
only finds what both sides fold the same way, so `HadithParityTests` folds every
probe here with the Swift code and compares it with what this script recorded
from the Python code.

The probes are the hand-written list in
`Packages/ArabicText/Tests/ArabicTextTests/Fixtures/parity-probes.txt`, plus one
generated probe per distinct character of today's `hadith.sqlite` text and
`quran.sqlite` verses, set between two letters (`ب` + character + `ب`) so the test
sees whether that character is kept, dropped or ends a word.

A probe is marked `quranOnly` when it contains the small waw or small yeh
(U+06E5, U+06E6): the Swift rule drops them and this Python rule keeps them as
letters. The script refuses to run if either appears in the hadith text, which
is what makes that one difference unable to reach the hadith index.
"""

from __future__ import annotations

import json
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_hadith_db import normalize  # noqa: E402  (the rule under test)

FIXTURES = ROOT / "Packages/ArabicText/Tests/ArabicTextTests/Fixtures"
PROBES = FIXTURES / "parity-probes.txt"
OUTPUT = FIXTURES / "hadith-parity.jsonl"
HADITH = ROOT / "ThawabForGod/Resources/Corpus/hadith.sqlite"
QURAN = ROOT / "ThawabForGod/Resources/Corpus/quran.sqlite"

QURAN_ONLY = {"\u06E5", "\u06E6"}
ESCAPE = re.compile(r"\\u\{([0-9A-Fa-f]{1,6})\}")


def unescape(line: str) -> str:
    """`\\u{XXXX}` to the character, and the two C escapes the list uses."""
    line = line.replace("\\n", "\n").replace("\\t", "\t")
    return ESCAPE.sub(lambda m: chr(int(m.group(1), 16)), line)


def hand_probes() -> list[str]:
    probes = []
    for raw in PROBES.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        probes.append(unescape(raw))
    return probes


def corpus_characters(path: Path, query: str) -> set[str]:
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as db:
        return {c for (text,) in db.execute(query) for c in text}


def main() -> int:
    hadith = corpus_characters(HADITH, "SELECT text FROM hadith")
    leaked = hadith & QURAN_ONLY
    if leaked:
        print(f"error: the hadith text contains {sorted(map(hex, map(ord, leaked)))}; "
              "the Swift and Python rules differ on those, so parity cannot hold.",
              file=sys.stderr)
        return 1

    quran = corpus_characters(QURAN, "SELECT text FROM verse")

    probes = hand_probes()
    generated = sorted(hadith | quran)
    probes += [f"\u0628{c}\u0628" for c in generated]

    rows = []
    seen = set()
    for probe in probes:
        if probe in seen:
            continue
        seen.add(probe)
        composed = unicodedata.normalize("NFC", probe)
        rows.append({
            "input": probe,
            "python": normalize(probe),
            "quranOnly": any(c in QURAN_ONLY for c in composed),
        })

    with OUTPUT.open("w", encoding="utf-8") as out:
        for row in rows:
            out.write(json.dumps(row, ensure_ascii=True) + "\n")

    print(f"{len(rows)} probes ({len(generated)} generated from "
          f"{len(hadith)} hadith and {len(quran)} Quran characters) -> "
          f"{OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
