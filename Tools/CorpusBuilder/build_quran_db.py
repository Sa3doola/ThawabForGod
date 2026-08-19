#!/usr/bin/env python3
"""Build the bundled Quran database.

Writes `ThawabForGod/Resources/Corpus/quran.sqlite` — the Uthmani text of the
Quran and the metadata a reader needs to navigate it:

- `surah`  — the 114 chapters: names, verse counts, where and when revealed,
             and the basmala each one opens with.
- `verse`  — all 6,236 verses, keyed by chapter and number, each carrying the
             divisions it falls in (juz, hizb, rub el hizb, mushaf page) and a
             search-normalized copy of its text.
- `juz`, `hizb`, `rub_el_hizb` — the reciter's divisions, as ranges to jump to.

Two FTS5 indexes come with it — `verse_fts` over the normalized text and
`surah_fts` over the three name spellings — built here rather than on device,
because an index over a read-only corpus is as static as the corpus is.

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
from typing import NamedTuple

TEXT_URL = (
    "https://tanzil.net/pub/download/index.php"
    "?quranType=uthmani&outType=txt-2&agree=true"
)
METADATA_URL = "https://tanzil.net/res/text/metadata/quran-data.xml"

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "quran.sqlite"

# Bumped whenever the shape below changes, so a reader can tell two builds apart.
# 1: surah + verse, Arabic only.
# 2: verse gains its divisions, the mushaf page, the sajdas and a normalized
#    column; juz/hizb/rub_el_hizb tables and the two FTS5 indexes arrive with it.
SCHEMA_VERSION = 2

SURAH_COUNT = 114
VERSE_COUNT = 6236
JUZ_COUNT = 30
HIZB_COUNT = 60
# Tanzil publishes the divisions as 240 *quarters* — the rub el hizb — and the
# coarser two fall out of them: four quarters to a hizb, eight to a juz.
QUARTER_COUNT = 240
QUARTERS_PER_HIZB = 4
PAGE_COUNT = 604
SAJDA_COUNT = 15

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
    bismillah             TEXT,
    -- `name_ar` folded the same way `verse.text_normalized` is, so searching
    -- "الفاتحه" with the wrong final letter still finds Al-Fatiha.
    name_ar_normalized    TEXT    NOT NULL
);

CREATE TABLE verse (
    surah_id        INTEGER NOT NULL REFERENCES surah(id),
    number          INTEGER NOT NULL CHECK (number > 0),
    text            TEXT    NOT NULL,
    -- The same verse with every diacritic dropped and the ambiguous letters
    -- folded together. Written here rather than computed on device: it is what
    -- search matches against, and normalizing 6,236 verses to answer one query
    -- would be the whole corpus walked per keystroke.
    text_normalized TEXT    NOT NULL,
    juz             INTEGER NOT NULL CHECK (juz BETWEEN 1 AND {JUZ_COUNT}),
    hizb            INTEGER NOT NULL CHECK (hizb BETWEEN 1 AND {HIZB_COUNT}),
    rub_el_hizb     INTEGER NOT NULL CHECK (rub_el_hizb BETWEEN 1 AND {QUARTER_COUNT}),
    -- The page of the Madina mushaf this verse begins on, so a later paged
    -- reading mode has the boundaries without a second data source.
    page            INTEGER NOT NULL CHECK (page BETWEEN 1 AND {PAGE_COUNT}),
    -- NULL for all but fifteen verses. Tanzil distinguishes the two kinds, and
    -- so does this: which prostrations are obligatory is not the app's to flatten.
    sajda           TEXT    CHECK (sajda IN ('obligatory', 'recommended')),
    PRIMARY KEY (surah_id, number)
);

-- The three divisions a reciter navigates by. Tanzil gives each as the verse it
-- *starts* on; the end is stored too, so "read juz 7" is one range query rather
-- than a lookup of where the next one begins.
CREATE TABLE juz (
    number       INTEGER PRIMARY KEY CHECK (number BETWEEN 1 AND {JUZ_COUNT}),
    start_surah  INTEGER NOT NULL REFERENCES surah(id),
    start_verse  INTEGER NOT NULL,
    end_surah    INTEGER NOT NULL REFERENCES surah(id),
    end_verse    INTEGER NOT NULL
);

CREATE TABLE hizb (
    number       INTEGER PRIMARY KEY CHECK (number BETWEEN 1 AND {HIZB_COUNT}),
    parent_juz   INTEGER NOT NULL REFERENCES juz(number),
    start_surah  INTEGER NOT NULL REFERENCES surah(id),
    start_verse  INTEGER NOT NULL
);

CREATE TABLE rub_el_hizb (
    number       INTEGER PRIMARY KEY CHECK (number BETWEEN 1 AND {QUARTER_COUNT}),
    parent_hizb  INTEGER NOT NULL REFERENCES hizb(number),
    start_surah  INTEGER NOT NULL REFERENCES surah(id),
    start_verse  INTEGER NOT NULL
);

-- Tanzil's terms require their copyright notice to be "reproduced appropriately
-- in all files derived from or containing substantial portion of this text".
-- This database is exactly that, so the notice travels inside it rather than
-- only in the README — a copy of the file on its own is still compliant.
CREATE TABLE source (
    id        TEXT PRIMARY KEY,
    name      TEXT NOT NULL,
    url       TEXT NOT NULL,
    licence   TEXT NOT NULL,
    notice    TEXT NOT NULL
);

-- External-content indexes: the text lives in the tables above and FTS5 keeps
-- only its index, which is what stops the corpus carrying two copies of the
-- Quran. Both are read-only in the app, so the triggers that would keep a
-- writable index in step are deliberately absent.
CREATE VIRTUAL TABLE verse_fts USING fts5(
    text_normalized,
    content = 'verse',
    content_rowid = 'rowid'
);

CREATE VIRTUAL TABLE surah_fts USING fts5(
    name_ar_normalized,
    transliteration,
    name_en,
    content = 'surah',
    content_rowid = 'id'
);
"""


class Divisions(NamedTuple):
    """Where every verse sits in the reciter's divisions, and the tables of them."""

    juz: dict[tuple[int, int], int]
    hizb: dict[tuple[int, int], int]
    rub_el_hizb: dict[tuple[int, int], int]
    page: dict[tuple[int, int], int]
    sajda: dict[tuple[int, int], str]
    juz_ranges: list[tuple[int, int, int, int]]
    hizb_starts: list[tuple[int, int]]
    quarter_starts: list[tuple[int, int]]


def divide(verses: list[tuple[int, int, str]], metadata: str) -> Divisions:
    """Read the divisions out of the metadata and place every verse in them.

    The hizb and the juz are not parsed: Tanzil publishes 240 quarters, and four
    quarters are a hizb and eight a juz by definition. Deriving them is what keeps
    the three from ever disagreeing — the failure a second parsed list invites.
    """
    positions = [(surah, number) for surah, number, _ in verses]

    juz_starts = parse_starts(metadata, "juzs", "juz", JUZ_COUNT)
    quarter_starts = parse_starts(metadata, "hizbs", "quarter", QUARTER_COUNT)
    page_starts = parse_starts(metadata, "pages", "page", PAGE_COUNT)

    hizb_starts = quarter_starts[::QUARTERS_PER_HIZB]
    if len(hizb_starts) != HIZB_COUNT:
        raise SystemExit(f"expected {HIZB_COUNT} hizbs, derived {len(hizb_starts)}")
    if quarter_starts[::QUARTERS_PER_HIZB * 2] != juz_starts:
        raise SystemExit(
            "the quarters and the juz boundaries disagree — every eighth quarter "
            "should be where a juz begins, and upstream no longer says so."
        )

    quarters = assign(verses, quarter_starts, "quarter")

    return Divisions(
        juz=assign(verses, juz_starts, "juz"),
        # Derived from the quarter each verse is in rather than assigned again,
        # so the three divisions cannot drift apart by a verse.
        hizb={
            position: (quarter - 1) // QUARTERS_PER_HIZB + 1
            for position, quarter in quarters.items()
        },
        rub_el_hizb=quarters,
        page=assign(verses, page_starts, "page"),
        sajda=parse_sajdas(metadata),
        juz_ranges=ranges(juz_starts, positions),
        hizb_starts=hizb_starts,
        quarter_starts=quarter_starts,
    )


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read().decode("utf-8")


def read_text(path: Path | None) -> str:
    return path.read_text(encoding="utf-8") if path else fetch(TEXT_URL)


def read_metadata(path: Path | None) -> str:
    return path.read_text(encoding="utf-8") if path else fetch(METADATA_URL)


def parse_notice(raw: str) -> str:
    """Tanzil's copyright block, verbatim, with the leading `#` markers stripped.

    Kept rather than discarded: their terms ask for it to be reproduced in derived
    files, and the database is one. Read out of the download instead of written
    out here so it cannot drift from what upstream actually said.
    """
    lines = [
        line.lstrip("#").strip()
        for line in raw.splitlines()
        if line.startswith("#")
    ]
    notice = "\n".join(line for line in lines if line and not set(line) <= {"="})

    if "Tanzil Project" not in notice:
        raise SystemExit(
            "the download carries no Tanzil copyright block. Their terms require "
            "it to be reproduced in derived files, so this is not shippable."
        )

    return notice


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


# What Arabic search has to fold together before a typed query can match a
# vowelled Uthmani text. The marks come off with `skeleton`; these are the
# letters that stay but are written more than one way.
LETTER_FOLDING = str.maketrans({
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",   # every hamza-bearing alef
    "ة": "ه",                                  # ta marbuta, which readers type as ha
    "ى": "ي",                                  # alef maqsura
    "ؤ": "و",
    "ئ": "ي",
    "ـ": "",                                   # tatweel, a typographic stretch
})


def normalize(text: str) -> str:
    """The form search matches against: no diacritics, one spelling per letter.

    A reader types الرحمن; the mushaf spells it ٱلرَّحْمَٰنِ. Folding both to the
    same string is the whole reason this column exists, and doing it here rather
    than on device means the FTS5 index below is built over the folded form and a
    query only has to be folded once.
    """
    return " ".join(skeleton(text).translate(LETTER_FOLDING).split())


def parse_starts(raw: str, container: str, tag: str, expected: int) -> list[tuple[int, int]]:
    """The `(surah, verse)` each section of `quran-data.xml` begins on, in order.

    Tanzil publishes every division — juz, quarter, page — the same way: as the
    single verse it starts at. One parser reads them all, and the caller says how
    many it should come back with, because a division silently short is a reader
    sent to the wrong page rather than an error.
    """
    root = ElementTree.fromstring(raw)
    element = root.find(container)
    if element is None:
        raise SystemExit(f"quran-data.xml has no <{container}> — upstream has changed shape")

    starts = [
        (int(child.attrib["sura"]), int(child.attrib["aya"]))
        for child in element.iter(tag)
    ]

    if len(starts) != expected:
        raise SystemExit(f"expected {expected} <{tag}> entries, metadata has {len(starts)}")
    if starts != sorted(starts):
        raise SystemExit(f"<{tag}> entries are not in canonical order")

    return starts


def parse_sajdas(raw: str) -> dict[tuple[int, int], str]:
    """The fifteen verses of prostration, each with which kind it is."""
    root = ElementTree.fromstring(raw)
    element = root.find("sajdas")
    if element is None:
        raise SystemExit("quran-data.xml has no <sajdas> — upstream has changed shape")

    sajdas = {
        (int(child.attrib["sura"]), int(child.attrib["aya"])): child.attrib["type"]
        for child in element.iter("sajda")
    }

    if len(sajdas) != SAJDA_COUNT:
        raise SystemExit(f"expected {SAJDA_COUNT} sajdas, metadata has {len(sajdas)}")

    unknown = set(sajdas.values()) - {"obligatory", "recommended"}
    if unknown:
        raise SystemExit(f"unknown sajda type(s): {sorted(unknown)}")

    return sajdas


def assign(
    verses: list[tuple[int, int, str]], starts: list[tuple[int, int]], what: str
) -> dict[tuple[int, int], int]:
    """Number every verse by which section it falls in.

    The boundaries are start markers, so a verse belongs to the last section that
    began at or before it — walked in canonical order, which is the order the
    Tanzil text file is already in.
    """
    boundaries = {position: index for index, position in enumerate(starts, start=1)}
    assigned: dict[tuple[int, int], int] = {}
    current = 0

    for surah, number, _ in verses:
        current = boundaries.get((surah, number), current)
        if current == 0:
            raise SystemExit(f"verse {surah}:{number} falls before the first {what}")
        assigned[(surah, number)] = current

    if current != len(starts):
        raise SystemExit(f"the last {what} ({len(starts)}) has no verses in it")

    return assigned


def ranges(
    starts: list[tuple[int, int]], positions: list[tuple[int, int]]
) -> list[tuple[int, int, int, int]]:
    """Turn start markers into closed ranges, each ending where the next begins.

    The verse before the next section's start is *not* `number - 1`: a section
    that opens on a new chapter ends on the last verse of the previous one. So the
    end is read back off `positions` — every verse in canonical order — rather
    than computed from the number.
    """
    index = {position: order for order, position in enumerate(positions)}
    ends = [positions[index[start] - 1] for start in starts[1:]] + [positions[-1]]

    return [
        (start[0], start[1], end[0], end[1]) for start, end in zip(starts, ends)
    ]


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
    divisions: Divisions,
    notice: str,
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
                revelation_place, revelation_order, bismillah, name_ar_normalized
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                row + (headings.get(row[0]), normalize(row[1]))
                for row in surahs
            ],
        )
        connection.executemany(
            """
            INSERT INTO verse (
                surah_id, number, text, text_normalized,
                juz, hizb, rub_el_hizb, page, sajda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    surah,
                    number,
                    text,
                    normalize(text),
                    divisions.juz[(surah, number)],
                    divisions.hizb[(surah, number)],
                    divisions.rub_el_hizb[(surah, number)],
                    divisions.page[(surah, number)],
                    divisions.sajda.get((surah, number)),
                )
                for surah, number, text in verses
            ],
        )
        connection.executemany(
            """
            INSERT INTO juz (number, start_surah, start_verse, end_surah, end_verse)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                (number,) + span
                for number, span in enumerate(divisions.juz_ranges, start=1)
            ],
        )
        connection.executemany(
            "INSERT INTO hizb (number, parent_juz, start_surah, start_verse) VALUES (?, ?, ?, ?)",
            [
                (number, (number - 1) // 2 + 1, surah, verse)
                for number, (surah, verse) in enumerate(divisions.hizb_starts, start=1)
            ],
        )
        connection.executemany(
            """
            INSERT INTO rub_el_hizb (number, parent_hizb, start_surah, start_verse)
            VALUES (?, ?, ?, ?)
            """,
            [
                (number, (number - 1) // QUARTERS_PER_HIZB + 1, surah, verse)
                for number, (surah, verse) in enumerate(divisions.quarter_starts, start=1)
            ],
        )

        connection.execute(
            "INSERT INTO source (id, name, url, licence, notice) VALUES (?, ?, ?, ?, ?)",
            (
                "tanzil",
                "Tanzil Project",
                "https://tanzil.net",
                "Creative Commons Attribution 3.0",
                notice,
            ),
        )

        # Filled by hand because both indexes are external-content and read-only:
        # nothing writes to the tables after this, so there are no triggers to keep
        # an index in step with — only this one load.
        connection.execute(
            "INSERT INTO verse_fts (rowid, text_normalized) "
            "SELECT rowid, text_normalized FROM verse"
        )
        connection.execute(
            "INSERT INTO surah_fts (rowid, name_ar_normalized, transliteration, name_en) "
            "SELECT id, name_ar_normalized, transliteration, name_en FROM surah"
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

    counts = {
        table: connection.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        for table in ("juz", "hizb", "rub_el_hizb")
    }
    pages = connection.execute("SELECT max(page) FROM verse").fetchone()[0]
    sajdas = connection.execute(
        "SELECT count(*) FROM verse WHERE sajda IS NOT NULL"
    ).fetchone()[0]
    indexed = connection.execute("SELECT count(*) FROM verse_fts").fetchone()[0]

    print(f"wrote {shown} ({output.stat().st_size} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")
    print(f"  {surahs} surahs ({meccan} Meccan, {surahs - meccan} Medinan)")
    print(f"  {verses} verses, {indexed} indexed for search")
    print(
        f"  {counts['juz']} juz, {counts['hizb']} hizb, "
        f"{counts['rub_el_hizb']} rub el hizb, {pages} pages"
    )
    print(f"  {sajdas} verses of prostration")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text", type=Path, help="a local copy of the Uthmani text")
    parser.add_argument("--metadata", type=Path, help="a local copy of quran-data.xml")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    text = read_text(arguments.text)
    verses = parse_verses(text)
    notice = parse_notice(text)
    metadata = read_metadata(arguments.metadata)
    surahs = parse_surahs(metadata)
    # Checked against the file exactly as it was downloaded, before the basmala is
    # moved — so the pinned digest tracks upstream rather than this script.
    check(verses, surahs)
    # Divided before the basmala is lifted off verse 1, for the same reason: the
    # boundaries are Tanzil's, and they are stated against Tanzil's numbering.
    divisions = divide(verses, metadata)
    split, headings = split_basmala(verses)
    build(split, surahs, headings, divisions, notice, arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
