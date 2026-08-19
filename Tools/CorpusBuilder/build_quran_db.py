#!/usr/bin/env python3
"""Build the bundled Quran database.

Writes `ThawabForGod/Resources/Corpus/quran.sqlite` — the Uthmani text of the
Quran and the metadata a reader needs to navigate it:

- `surah`  — the 114 chapters: names, verse counts, where and when revealed,
             and the basmala each one opens with.
- `verse`  — all 6,236 verses, keyed by chapter and number.

Its own file rather than more tables in `corpus.sqlite`, which
`Resources/Corpus/README.md` anticipated: the text is an order of magnitude
larger than everything else in there put together, it has a different upstream
and a different licence, and `CorpusDatabase` is constructed with a resource
name and knows nothing about what is inside it.

Both inputs come from the Tanzil Project (https://tanzil.net) and are used
verbatim — see the README for the terms, which require that and require the
attribution the app carries in Settings → Sources.

Nothing is edited by hand. Re-running this script reproduces the database from
scratch, which is what makes a correction reviewable.

Usage:
    python3 Tools/CorpusBuilder/build_quran_db.py            # downloads upstream
    python3 Tools/CorpusBuilder/build_quran_db.py --text path/to/quran-uthmani.txt
"""

from __future__ import annotations

import argparse
import hashlib
import sqlite3
import sys
import unicodedata
import urllib.request
import xml.etree.ElementTree as ElementTree
from pathlib import Path

TEXT_URL = (
    "https://tanzil.net/pub/download/index.php"
    "?quranType=uthmani&outType=txt-2&agree=true"
)
METADATA_URL = "https://tanzil.net/res/text/metadata/quran-data.xml"

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "quran.sqlite"

# Bumped whenever the shape below changes, so a reader can tell two builds apart.
# 1: surah + verse, Arabic only.
SCHEMA_VERSION = 1

SURAH_COUNT = 114
VERSE_COUNT = 6236

# SHA-256 of the *verses alone*, joined as `sura|aya|text` lines — not of the
# downloaded file, whose copyright block carries the current year and so changes
# on its own every January. Pinned so that an upstream revision of the text is a
# loud build failure to be looked at and re-pinned deliberately, rather than a
# silent change to the mushaf the app ships.
TEXT_DIGEST = "36da55e256f54f4838b6fa1c78781734346c8d9ffde52daf5a3cbfa32626a08c"

# Al-Fatiha opens *with* the basmala as its first verse — numbered, part of the
# chapter — and At-Tawba is the one chapter that does not begin with it at all.
# Those two get no heading; the other 112 do.
NO_BISMILLAH_HEADING = {1, 9}

# Tanzil delivers the basmala as a *prefix of verse 1* for those 112 chapters.
# The mushaf prints it above the chapter instead, unnumbered, so the build moves
# it into `surah.bismillah` and the reading screen draws it as a heading. The
# reader sees the same words in the same order; what changes is which line they
# sit on, and the prefix is stored exactly as it arrived rather than rewritten.
# (The Tazkiya Tech Quran SDK, working from the same upstream, makes the same
# cut for the same reason — see the README.)
#
# There is deliberately no basmala string written out below. It is read from
# verse 1:1, which *is* the basmala, and a prefix is recognised by comparing
# letters with the diacritics removed — because two chapters, Al-Tin and
# Al-Qadr, carry an extra shadda on the opening ba (the idgham from the end of
# the preceding chapter, a recitation mark of the Madina text) and because the
# order of combining marks in a literal pasted into this file is not something
# to stake the build on.


SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};

CREATE TABLE surah (
    id                    INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND {SURAH_COUNT}),
    name_ar               TEXT    NOT NULL,
    transliteration       TEXT    NOT NULL,
    name_en               TEXT    NOT NULL,
    verse_count           INTEGER NOT NULL CHECK (verse_count > 0),
    revelation_place      TEXT    NOT NULL CHECK (revelation_place IN ('meccan', 'medinan')),
    revelation_order      INTEGER NOT NULL,
    -- The heading above the chapter, verbatim as Tanzil delivered it. NULL for
    -- Al-Fatiha, whose basmala is verse 1, and for At-Tawba, which has none.
    bismillah             TEXT
);

CREATE TABLE verse (
    surah_id  INTEGER NOT NULL REFERENCES surah(id),
    number    INTEGER NOT NULL CHECK (number > 0),
    text      TEXT    NOT NULL,
    PRIMARY KEY (surah_id, number)
);
"""


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read().decode("utf-8")


def read_text(path: Path | None) -> str:
    return path.read_text(encoding="utf-8") if path else fetch(TEXT_URL)


def read_metadata(path: Path | None) -> str:
    return path.read_text(encoding="utf-8") if path else fetch(METADATA_URL)


def parse_verses(raw: str) -> list[tuple[int, int, str]]:
    """`sura|aya|text` lines, with the copyright block and blank lines dropped."""
    verses: list[tuple[int, int, str]] = []

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        surah, number, text = line.split("|", 2)
        text = text.strip()
        if not text:
            raise SystemExit(f"verse {surah}:{number} is empty upstream")
        verses.append((int(surah), int(number), text))

    return verses


def parse_surahs(raw: str) -> list[tuple[int, str, str, str, int, str, int]]:
    root = ElementTree.fromstring(raw)
    rows = []

    for element in root.iter("sura"):
        rows.append(
            (
                int(element.attrib["index"]),
                element.attrib["name"],
                element.attrib["tname"],
                element.attrib["ename"],
                int(element.attrib["ayas"]),
                element.attrib["type"].lower(),
                int(element.attrib["order"]),
            )
        )

    return sorted(rows)


def skeleton(text: str) -> str:
    """The letters alone — every combining mark dropped.

    Used only for *recognising* the basmala, never for storing it: two spellings
    that differ in their vowel marks, or in the order those marks were encoded
    in, are the same four words for the purpose of deciding where verse 1 begins.
    """
    return "".join(c for c in text if not unicodedata.combining(c))


def split_basmala(
    verses: list[tuple[int, int, str]]
) -> tuple[list[tuple[int, int, str]], dict[int, str]]:
    """Lifts the basmala off verse 1 and hands it back as a per-chapter heading."""
    canonical = next(text for surah, number, text in verses if (surah, number) == (1, 1))
    canonical_key = skeleton(canonical)
    word_count = len(canonical.split())

    headings: dict[int, str] = {}
    split: list[tuple[int, int, str]] = []

    for surah, number, text in verses:
        if number != 1 or surah in NO_BISMILLAH_HEADING:
            split.append((surah, number, text))
            continue

        words = text.split()
        prefix = " ".join(words[:word_count])
        remainder = " ".join(words[word_count:])

        if skeleton(prefix) != canonical_key:
            raise SystemExit(
                f"surah {surah}: verse 1 does not open with the basmala. Upstream's "
                "delimiting has changed — look at it before adapting this."
            )
        if not remainder:
            raise SystemExit(f"surah {surah}: verse 1 is the basmala and nothing else")

        headings[surah] = prefix
        split.append((surah, number, remainder))

    expected = SURAH_COUNT - len(NO_BISMILLAH_HEADING)
    if len(headings) != expected:
        raise SystemExit(f"expected {expected} basmala headings, found {len(headings)}")

    return split, headings


def check(verses: list[tuple[int, int, str]], surahs: list[tuple]) -> None:
    """Everything that would be a silently wrong mushaf rather than an error."""
    if len(surahs) != SURAH_COUNT:
        raise SystemExit(f"expected {SURAH_COUNT} surahs, metadata has {len(surahs)}")
    if len(verses) != VERSE_COUNT:
        raise SystemExit(f"expected {VERSE_COUNT} verses, the text has {len(verses)}")

    digest = hashlib.sha256(
        "\n".join(f"{s}|{n}|{t}" for s, n, t in verses).encode("utf-8")
    ).hexdigest()
    if digest != TEXT_DIGEST:
        raise SystemExit(
            "the Tanzil text has changed upstream.\n"
            f"  expected {TEXT_DIGEST}\n"
            f"  got      {digest}\n"
            "Read tanzil.net/updates before re-pinning: this is the text of the "
            "Quran, and a diff here is not a routine dependency bump."
        )

    counted: dict[int, int] = {}
    for surah, number, _ in verses:
        counted[surah] = counted.get(surah, 0) + 1

    for row in surahs:
        index, _, _, _, expected, *_ = row
        if counted.get(index) != expected:
            raise SystemExit(
                f"surah {index}: metadata says {expected} verses, the text has "
                f"{counted.get(index, 0)}"
            )

    # The verses of a surah must be 1..n with nothing missing and nothing repeated,
    # which the count above cannot see on its own.
    numbers: dict[int, set[int]] = {}
    for surah, number, _ in verses:
        numbers.setdefault(surah, set()).add(number)
    for index, expected in ((row[0], row[4]) for row in surahs):
        if numbers[index] != set(range(1, expected + 1)):
            raise SystemExit(f"surah {index}: verse numbers are not 1..{expected}")


def build(
    verses: list[tuple[int, int, str]],
    surahs: list[tuple],
    headings: dict[int, str],
    output: Path,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        connection.executemany(
            """
            INSERT INTO surah (
                id, name_ar, transliteration, name_en, verse_count,
                revelation_place, revelation_order, bismillah
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [row + (headings.get(row[0]),) for row in surahs],
        )
        connection.executemany(
            "INSERT INTO verse (surah_id, number, text) VALUES (?, ?, ?)", verses
        )
        connection.commit()

        # Read-only from here on, so there is no reason to ship free pages.
        connection.execute("VACUUM")
        connection.commit()

        report(connection, output)
    finally:
        connection.close()


def report(connection: sqlite3.Connection, output: Path) -> None:
    surahs = connection.execute("SELECT count(*) FROM surah").fetchone()[0]
    verses = connection.execute("SELECT count(*) FROM verse").fetchone()[0]
    meccan = connection.execute(
        "SELECT count(*) FROM surah WHERE revelation_place = 'meccan'"
    ).fetchone()[0]

    try:
        shown = output.relative_to(REPO_ROOT)
    except ValueError:
        shown = output

    print(f"wrote {shown} ({output.stat().st_size} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")
    print(f"  {surahs} surahs ({meccan} Meccan, {surahs - meccan} Medinan)")
    print(f"  {verses} verses")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text", type=Path, help="a local copy of the Uthmani text")
    parser.add_argument("--metadata", type=Path, help="a local copy of quran-data.xml")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    verses = parse_verses(read_text(arguments.text))
    surahs = parse_surahs(read_metadata(arguments.metadata))
    # Checked against the file exactly as it was downloaded, before the basmala is
    # moved — so the pinned digest tracks upstream rather than this script.
    check(verses, surahs)
    split, headings = split_basmala(verses)
    build(split, surahs, headings, arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
