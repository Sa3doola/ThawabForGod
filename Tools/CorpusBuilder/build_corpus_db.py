#!/usr/bin/env python3
"""Build the bundled corpus database.

Writes `ThawabForGod/Resources/Corpus/corpus.sqlite`, the app's read-only
reference content. One file, one table set per feature:

- `adhkar` / `dhikr_category` — the morning and evening adhkar, joined here
  from the two per-language JSON files published by
  Seen-Arabic/Morning-And-Evening-Adhkar-DB (MIT).
- `tasbih_preset` — the five phrases the counter offers, written out below
  rather than sourced, because they are five short universally-known phrases
  and there is no upstream worth depending on for them.
- `divine_name` — the 99 names, read from `data/divine_names.json`, which is
  vendored rather than downloaded: see the README for how it was derived and
  cross-checked, and why it is not fetched at build time.

Nothing is edited by hand. Re-running this script reproduces the database from
scratch, which is what makes a correction reviewable.

Usage:
    python3 Tools/CorpusBuilder/build_corpus_db.py           # downloads upstream
    python3 Tools/CorpusBuilder/build_corpus_db.py --source-dir path/to/checkout
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

UPSTREAM = "https://raw.githubusercontent.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB/HEAD/{}"

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "corpus.sqlite"
DIVINE_NAMES_FILE = Path(__file__).resolve().parent / "data" / "divine_names.json"

# Bumped whenever the shape below changes, so a reader can tell two builds apart.
# 1: adhkar only. 2: adds tasbih_preset. 3: adds divine_name.
SCHEMA_VERSION = 3

# Upstream's `type` column: 0 = both morning and evening, 1 = morning only,
# 2 = evening only. Expanded here into the category memberships our join table
# stores, which is what lets a single dhikr appear under both headings.
CATEGORIES_FOR_TYPE = {
    0: ("morning", "evening"),
    1: ("morning",),
    2: ("evening",),
}

# `id` is the category's stable identifier and matches `AdhkarCategory`'s raw
# value in Swift. Adding a category later means adding a row here and the rows
# that belong to it — not editing the enum's storage.
CATEGORIES = [("morning", 0), ("evening", 1)]

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

SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};

CREATE TABLE category (
    id          TEXT PRIMARY KEY,
    sort_order  INTEGER NOT NULL
);

CREATE TABLE dhikr (
    id                  INTEGER PRIMARY KEY,
    arabic_text         TEXT NOT NULL,
    translation_en      TEXT NOT NULL,
    transliteration_en  TEXT,
    reference_ar        TEXT NOT NULL,
    reference_en        TEXT NOT NULL,
    virtue_ar           TEXT,
    virtue_en           TEXT,
    repeat_count        INTEGER NOT NULL
);

CREATE TABLE dhikr_category (
    dhikr_id     INTEGER NOT NULL REFERENCES dhikr(id),
    category_id  TEXT    NOT NULL REFERENCES category(id),
    sort_order   INTEGER NOT NULL,
    PRIMARY KEY (dhikr_id, category_id)
);

CREATE INDEX index_dhikr_category_on_category
    ON dhikr_category(category_id, sort_order);

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


def load(name: str, source_dir: Path | None) -> list[dict]:
    if source_dir is not None:
        return json.loads((source_dir / name).read_text(encoding="utf-8"))

    with urllib.request.urlopen(UPSTREAM.format(name), timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def text_or_none(value: object) -> str | None:
    """Upstream leaves an absent field as an empty string; SQL wants NULL."""
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    return stripped or None


def required(value: object, field: str, order: object) -> str:
    text = text_or_none(value)
    if text is None:
        raise SystemExit(f"dhikr {order}: required field '{field}' is empty upstream")
    return text


def insert_adhkar(connection: sqlite3.Connection, arabic: list[dict], english: list[dict]) -> None:
    by_order_en = {row["order"]: row for row in english}
    if {row["order"] for row in arabic} != set(by_order_en):
        raise SystemExit("the two upstream files do not cover the same set of adhkar")

    connection.executemany(
        "INSERT INTO category (id, sort_order) VALUES (?, ?)", CATEGORIES
    )

    for ar in sorted(arabic, key=lambda row: row["order"]):
        order = ar["order"]
        en = by_order_en[order]

        if ar["content"] != en["content"]:
            raise SystemExit(f"dhikr {order}: Arabic text differs between the two files")
        if ar["type"] != en["type"]:
            raise SystemExit(f"dhikr {order}: category differs between the two files")

        connection.execute(
            """
            INSERT INTO dhikr (
                id, arabic_text, translation_en, transliteration_en,
                reference_ar, reference_en, virtue_ar, virtue_en, repeat_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                order,
                required(ar["content"], "content", order),
                required(en.get("translation"), "translation", order),
                text_or_none(en.get("transliteration")),
                required(ar.get("source"), "source (ar)", order),
                required(en.get("source"), "source (en)", order),
                text_or_none(ar.get("fadl")),
                text_or_none(en.get("fadl")),
                int(ar["count"]),
            ),
        )

        for category in CATEGORIES_FOR_TYPE[ar["type"]]:
            connection.execute(
                "INSERT INTO dhikr_category (dhikr_id, category_id, sort_order)"
                " VALUES (?, ?, ?)",
                (order, category, order),
            )


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
                text_or_none(row.get("explanation_en")),
                text_or_none(row.get("reference")),
            ),
        )


def insert_tasbih(connection: sqlite3.Connection) -> None:
    connection.executemany(
        "INSERT INTO tasbih_preset (id, arabic_text, translation_en, target_count, sort_order)"
        " VALUES (?, ?, ?, ?, ?)",
        TASBIH_PRESETS,
    )


def build(arabic: list[dict], english: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        insert_adhkar(connection, arabic, english)
        insert_tasbih(connection)
        insert_divine_names(connection)
        connection.commit()

        # Read-only from here on, so there is no reason to ship free pages.
        connection.execute("VACUUM")
        connection.commit()

        report(connection, output)
    finally:
        connection.close()


def report(connection: sqlite3.Connection, output: Path) -> None:
    total = connection.execute("SELECT count(*) FROM dhikr").fetchone()[0]
    rows = connection.execute(
        """
        SELECT category.id, count(dhikr_category.dhikr_id)
        FROM category
        LEFT JOIN dhikr_category ON dhikr_category.category_id = category.id
        GROUP BY category.id
        ORDER BY category.sort_order
        """
    ).fetchall()
    presets = connection.execute("SELECT count(*) FROM tasbih_preset").fetchone()[0]
    names = connection.execute("SELECT count(*) FROM divine_name").fetchone()[0]

    print(f"wrote {output.relative_to(REPO_ROOT)} ({output.stat().st_size} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")
    print(f"  {total} adhkar")
    for name, count in rows:
        print(f"    {name}: {count}")
    print(f"  {presets} tasbih presets")
    print(f"  {names} divine names")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="a local checkout of the adhkar repo; downloads from GitHub when omitted",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    build(
        load("ar.json", arguments.source_dir),
        load("en.json", arguments.source_dir),
        arguments.output,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
