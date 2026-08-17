#!/usr/bin/env python3
"""Build the bundled adhkar corpus database.

Reads the two upstream JSON files from Seen-Arabic/Morning-And-Evening-Adhkar-DB
(MIT) and writes `ThawabForGod/Resources/Corpus/adhkar.sqlite` in *our* schema.

Why we generate rather than ship theirs: upstream publishes one SQLite per
language (`ar.sqlite`, `en.sqlite`), each a flat dump of its JSON. The app needs
one bilingual row per dhikr — the Arabic text is shown to everyone and only the
translation, transliteration, citation and virtue vary by language — and it needs
a dhikr to belong to more than one category, which a flat `type` integer cannot
express. So the two files are joined here, once, at build time.

Nothing is edited by hand. Re-running this script against a newer upstream
revision reproduces the database from scratch.

Usage:
    python3 Tools/CorpusBuilder/build_adhkar_db.py           # downloads upstream
    python3 Tools/CorpusBuilder/build_adhkar_db.py --source-dir path/to/checkout
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
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "adhkar.sqlite"

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

SCHEMA = """
PRAGMA user_version = 1;

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


def build(arabic: list[dict], english: list[dict], output: Path) -> None:
    by_order_en = {row["order"]: row for row in english}
    if {row["order"] for row in arabic} != set(by_order_en):
        raise SystemExit("the two upstream files do not cover the same set of adhkar")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
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

    print(f"wrote {output.relative_to(REPO_ROOT)} ({output.stat().st_size} bytes)")
    print(f"  {total} adhkar")
    for name, count in rows:
        print(f"  {name}: {count}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="a local checkout of the upstream repo; downloads from GitHub when omitted",
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
