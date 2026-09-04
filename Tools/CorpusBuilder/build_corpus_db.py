#!/usr/bin/env python3
"""Build the bundled corpus database.

Writes `ThawabForGod/Resources/Corpus/corpus.sqlite`, the app's read-only
reference content. One file, one table set per feature:

- `category_group` / `category` / `dhikr` — Hisn al-Muslim, all 132 chapters,
  read from `data/adhkar.json` (vendored) and `data/adhkar_categories.json`
  (this project's own slugs, English chapter titles and grouping).
- `tasbih_preset` — the five phrases the counter offers, written out below
  rather than sourced, because they are five short universally-known phrases
  and there is no upstream worth depending on for them.
- `divine_name` — the 99 names, read from `data/divine_names.json`, which is
  vendored rather than downloaded: see the README for how it was derived and
  cross-checked, and why it is not fetched at build time.

Nothing is edited by hand. Re-running this script reproduces the database from
scratch, which is what makes a correction reviewable.

Usage:
    python3 Tools/CorpusBuilder/build_corpus_db.py
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).resolve().parent / "data"
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "corpus.sqlite"

ADHKAR_FILE = DATA / "adhkar.json"
ADHKAR_CATEGORIES_FILE = DATA / "adhkar_categories.json"
DIVINE_NAMES_FILE = DATA / "divine_names.json"

# Bumped whenever the shape below changes, so a reader can tell two builds apart.
# 1: adhkar only. 2: adds tasbih_preset. 3: adds divine_name.
# 4: the adhkar become the whole of Hisn al-Muslim — 132 chapters, Arabic only,
#    keyed on a slug rather than on a two-case enum, and grouped.
SCHEMA_VERSION = 4

# The groups the 132 chapters are gathered into, in the order the app lists them.
#
# This grouping is **this project's**, not the book's: Hisn al-Muslim is one flat
# sequence of chapters, which is fine bound in the hand and unusable as 132 rows
# on a phone. The sequence itself is not lost — `category.sort_order` is the
# book's own order, and a group is only how the list is broken up. Which chapter
# sits in which group is in `data/adhkar_categories.json` so it reads as a data
# decision that can be argued with, rather than as a `switch` in a view.
GROUPS = [
    "daily",
    "purification",
    "prayer",
    "home",
    "food",
    "travel",
    "hajj",
    "distress",
    "illness",
    "nature",
    "social",
    "praise",
]

# Corrections to the vendored text, applied at build time and listed here rather
# than edited into `data/adhkar.json`, so that the vendored file stays byte-equal
# to what was downloaded and every departure from it is reviewable as code.
#
# All of these are transcription damage from the upstream file's PDF origin, not
# textual variants: `نز` came out as `تر` under a legacy encoding, which turns
# منزلا into the non-word مترلا.
CORRECTIONS = {
    "مترلا": "منزلا",
    "مترل": "منزل",
}

# The written number that opens a `(… times)` note, and what it means. Used only
# to *check* the `count` field against the chapter's own prose — nothing here is
# ever written to the database.
WRITTEN_COUNTS = {
    "مرة": 1, "مرَّة": 1, "مرَّةً": 1, "مرةً": 1,
    "مرتين": 2, "مرَّتين": 2,
    "ثلاث": 3, "ثلاثَ": 3, "ثلاثا": 3, "ثلاثاً": 3,
    "أربع": 4, "أربعَ": 4,
    "خمس": 5, "خمسَ": 5,
    "سبع": 7, "سبعَ": 7, "سبعاً": 7, "سبعا": 7,
    "عشر": 10, "عشرَ": 10, "عشراً": 10, "عشرا": 10,
    "مائة": 100, "مائةَ": 100, "مِائَةَ": 100, "مئة": 100,
}

SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};

CREATE TABLE category_group (
    id          TEXT PRIMARY KEY,
    sort_order  INTEGER NOT NULL
);

CREATE TABLE category (
    id          TEXT PRIMARY KEY,
    title_ar    TEXT NOT NULL,
    title_en    TEXT NOT NULL,
    group_id    TEXT NOT NULL REFERENCES category_group(id),
    sort_order  INTEGER NOT NULL
);

CREATE INDEX index_category_on_group ON category(group_id, sort_order);

CREATE TABLE dhikr (
    id            INTEGER PRIMARY KEY,
    category_id   TEXT    NOT NULL REFERENCES category(id),
    sort_order    INTEGER NOT NULL,
    arabic_text   TEXT    NOT NULL,
    repeat_count  INTEGER NOT NULL CHECK (repeat_count > 0)
);

CREATE INDEX index_dhikr_on_category ON dhikr(category_id, sort_order);

CREATE TABLE tasbih_preset (
    id              TEXT PRIMARY KEY,
    arabic_text     TEXT NOT NULL,
    translation_en  TEXT NOT NULL,
    target_count    INTEGER NOT NULL CHECK (target_count > 0),
    sort_order      INTEGER NOT NULL
);

CREATE TABLE divine_name (
    id               INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 99),
    arabic           TEXT NOT NULL,
    transliteration  TEXT NOT NULL,
    meaning_en       TEXT NOT NULL,
    -- Deliberately empty for now. Every freely-licensed set of explanations
    -- found for these names was AI-generated; the column waits for a source
    -- somebody has actually checked. See the README.
    explanation_en   TEXT,
    -- Where the name occurs in the Quran, as chapter:verse citations.
    reference        TEXT
);
"""

# The tasbih presets: id, Arabic, English, target, sort order.
#
# The ids match `TasbihDhikr`'s identifiers in Swift and are what the SwiftData
# progress store keys a session on — so changing one orphans a user's count.
#
# On the targets: 33/33/34 is the tasbih after an obligatory prayer, which is
# where those three numbers come from and why they sum to 100. The 100s on the
# last two are the counts most commonly given for them as a daily practice.
# None of these is the only reported form — see the README.
TASBIH_PRESETS = [
    ("subhanallah", "سُبْحَانَ اللَّهِ", "Glory be to Allah", 33, 0),
    ("alhamdulillah", "الْحَمْدُ لِلَّهِ", "All praise is due to Allah", 33, 1),
    ("allahuakbar", "اللَّهُ أَكْبَرُ", "Allah is the Greatest", 34, 2),
    (
        "lailahaillallah",
        "لَا إِلَٰهَ إِلَّا اللَّهُ",
        "There is no god but Allah",
        100,
        3,
    ),
    ("astaghfirullah", "أَسْتَغْفِرُ اللَّهَ", "I seek forgiveness from Allah", 100, 4),
]


# MARK: Cleaning


def clean(text: str) -> str:
    """Normalise what the upstream file spells oddly, and nothing else.

    Three passes, each mechanical:

    - **NFKC**, which folds the Arabic presentation forms the source carries in
      three of its chapter titles — `اﻟﻤﺠلس` is written with initial/medial
      glyph codepoints rather than with letters, so it fails every search and
      every comparison while looking correct on screen. The ornate parentheses
      `﴿ ﴾` that mark Quranic quotation have no NFKC mapping and survive intact,
      which is what makes this safe to apply to the text and not only to titles.
    - **The corrections table above**, which is transcription damage.
    - **Whitespace**, collapsed to single spaces. The source has runs of two and
      three where a line broke in the PDF it came from.
    """
    text = unicodedata.normalize("NFKC", text)
    for wrong, right in CORRECTIONS.items():
        text = text.replace(wrong, right)
    return re.sub(r"\s+", " ", text).strip()


def stated_count(text: str) -> int | None:
    """The repeat count the dhikr's own prose gives, where it gives one unambiguously.

    Hisn al-Muslim writes the number in words inside a trailing parenthesis —
    `(ثلاثَ مرَّاتٍ)`, `(سَبْعَ مَرّاتٍ)`. The upstream file carries a `count`
    field beside the text, and the two do not always agree; where the prose is
    unambiguous it is the one that ships, because the prose is the book's own
    words and the count field is somebody's metadata about them.

    Two conditions, and both were earned by a case that breaks without them:

    - **Every count note in the text must agree.** The morning dhikr `لا إله إلا
      الله وحده...` is written `(عشرَ مرَّات) ، أَوْ (مرَّةً واحدةً عند الكسل)` —
      ten times, or once when tired. That is a choice the book offers, not a
      number to be read off, so it is reported and left alone.
    - **The last parenthesis in the text must be the note.** The chapter on
      dreams is a bracketed list of *actions* — spit to the left `(three times)`,
      seek refuge `(three times)`, tell no one — where the number governs one
      step rather than the whole. There the trailing parenthesis is prose, so
      nothing is read.

    Returns `None` where the text says nothing, which is most of them.
    """
    groups = re.findall(r"\(([^()]{1,60})\)", text)
    if not groups:
        return None

    values = [value for value in map(count_note, groups) if value is not None]
    if not values or len(set(values)) != 1:
        return None

    # The note that governs the whole dhikr is written at its end.
    return values[0] if count_note(groups[-1]) is not None else None


def count_note(group: str) -> int | None:
    """`ثلاثَ مرَّاتٍ` → 3. `صلى الله عليه وسلم` → None."""
    words = group.split()
    # A note opens with the number and says مرة/مرات. Without the second half,
    # `(ثلاثة أيام)` would be read as a repeat count.
    if not words or not any(word.startswith(("مر", "مَر", "مِر")) for word in words):
        return None

    stripped = strip_diacritics(words[0])
    for written, value in WRITTEN_COUNTS.items():
        if strip_diacritics(written) == stripped:
            return value
    return None


def strip_diacritics(text: str) -> str:
    return "".join(c for c in text if not ("ً" <= c <= "ْ"))


# MARK: The adhkar


def insert_adhkar(connection: sqlite3.Connection) -> list[str]:
    """Loads Hisn al-Muslim into `category_group` / `category` / `dhikr`.

    Returns the warnings worth printing — none of them fatal, because every one
    of them is a question about the book rather than about the file.
    """
    chapters = json.loads(ADHKAR_FILE.read_text(encoding="utf-8"))
    metadata = json.loads(ADHKAR_CATEGORIES_FILE.read_text(encoding="utf-8"))

    by_source = {row["source_id"]: row for row in metadata}
    if sorted(by_source) != sorted(chapter["id"] for chapter in chapters):
        raise SystemExit("adhkar_categories.json does not cover the same chapters as adhkar.json")
    if len({row["slug"] for row in metadata}) != len(metadata):
        raise SystemExit("adhkar_categories.json has a duplicate slug")

    unknown = {row["group"] for row in metadata} - set(GROUPS)
    if unknown:
        raise SystemExit(f"adhkar_categories.json names groups this build has no case for: {unknown}")

    connection.executemany(
        "INSERT INTO category_group (id, sort_order) VALUES (?, ?)",
        [(name, order) for order, name in enumerate(GROUPS)],
    )

    warnings: list[str] = []

    for chapter in sorted(chapters, key=lambda c: c["id"]):
        row = by_source[chapter["id"]]
        title = clean(chapter["category"])
        if not title:
            raise SystemExit(f"chapter {chapter['id']}: empty title")

        connection.execute(
            "INSERT INTO category (id, title_ar, title_en, group_id, sort_order)"
            " VALUES (?, ?, ?, ?, ?)",
            (row["slug"], title, row["title_en"].strip(), row["group"], chapter["id"]),
        )

        if not chapter["array"]:
            raise SystemExit(f"chapter {chapter['id']}: no adhkar — it would be a row leading nowhere")

        for order, item in enumerate(chapter["array"]):
            text = clean(item["text"])
            if not text:
                raise SystemExit(f"chapter {chapter['id']}, dhikr {item['id']}: empty text")

            count = int(item["count"])
            if count < 1:
                raise SystemExit(f"chapter {chapter['id']}, dhikr {item['id']}: count below one")

            written = stated_count(text)
            if written is not None and written != count:
                warnings.append(
                    f"{row['slug']} #{item['id']}: "
                    f"the text says {written}, the count field said {count} — the text ships"
                )
                count = written

            connection.execute(
                "INSERT INTO dhikr (id, category_id, sort_order, arabic_text, repeat_count)"
                " VALUES (?, ?, ?, ?, ?)",
                # Derived from the source's own two ids rather than from insertion
                # order, so a rebuild cannot silently renumber a dhikr that a
                # bookmark or an activity record is keyed on.
                (chapter["id"] * 1000 + item["id"], row["slug"], order, text, count),
            )

    return warnings


def insert_divine_names(connection: sqlite3.Connection) -> None:
    names = json.loads(DIVINE_NAMES_FILE.read_text(encoding="utf-8"))

    # The list is exactly 99, in order, or the build is wrong. Asserted here rather
    # than left to a test: a corpus that ships 98 names is not a thing to discover
    # later.
    if [row["order"] for row in names] != list(range(1, 100)):
        raise SystemExit("divine_names.json must hold exactly 99 names, ordered 1-99")

    for row in names:
        for field in ("arabic", "transliteration", "meaning_en"):
            if not row.get(field, "").strip():
                raise SystemExit(f"name {row['order']}: '{field}' is empty")

        connection.execute(
            """
            INSERT INTO divine_name
                (id, arabic, transliteration, meaning_en, explanation_en, reference)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                row["order"],
                row["arabic"].strip(),
                row["transliteration"].strip(),
                row["meaning_en"].strip(),
                (row.get("explanation_en") or "").strip() or None,
                (row.get("reference") or "").strip() or None,
            ),
        )


def insert_tasbih(connection: sqlite3.Connection) -> None:
    connection.executemany(
        "INSERT INTO tasbih_preset (id, arabic_text, translation_en, target_count, sort_order)"
        " VALUES (?, ?, ?, ?, ?)",
        TASBIH_PRESETS,
    )


def build(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        warnings = insert_adhkar(connection)
        insert_tasbih(connection)
        insert_divine_names(connection)
        connection.commit()

        # Read-only from here on, so there is no reason to ship free pages.
        connection.execute("VACUUM")
        connection.commit()

        report(connection, output, warnings)
    finally:
        connection.close()


def report(connection: sqlite3.Connection, output: Path, warnings: list[str]) -> None:
    categories = connection.execute("SELECT count(*) FROM category").fetchone()[0]
    total = connection.execute("SELECT count(*) FROM dhikr").fetchone()[0]
    rows = connection.execute(
        """
        SELECT category_group.id,
               count(DISTINCT category.id),
               count(dhikr.id)
        FROM category_group
        LEFT JOIN category ON category.group_id = category_group.id
        LEFT JOIN dhikr ON dhikr.category_id = category.id
        GROUP BY category_group.id
        ORDER BY category_group.sort_order
        """
    ).fetchall()
    presets = connection.execute("SELECT count(*) FROM tasbih_preset").fetchone()[0]
    names = connection.execute("SELECT count(*) FROM divine_name").fetchone()[0]

    print(f"wrote {output.relative_to(REPO_ROOT)} ({output.stat().st_size} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")
    print(f"  {categories} categories, {total} adhkar")
    for name, chapters, adhkar in rows:
        print(f"    {name}: {chapters} categories, {adhkar} adhkar")
    print(f"  {presets} tasbih presets")
    print(f"  {names} divine names")

    if warnings:
        print(f"\n  {len(warnings)} repeat counts taken from the text rather than the count field:")
        for warning in warnings:
            print(f"    {warning}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    build(parser.parse_args().output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
