#!/usr/bin/env python3
"""Build the bundled tafsir database.

Writes `ThawabForGod/Resources/Corpus/tafsir.sqlite` — a per-verse commentary on
the Quran, in Arabic:

- `edition` — one row per tafsir, with its author, its language and the reason
              this project believes it may ship it.
- `tafsir`  — the notes, keyed by edition and verse.

Its own file rather than more tables in `quran.sqlite`, for the reason that file
was split off `corpus.sqlite`: a different upstream, a different licence, and a
size that grows with every edition added. `CorpusDatabase` is constructed with a
resource name and knows nothing about what is inside it, so a third file costs
nothing.

## Why al-Jalalayn, and why Arabic only

**Every distributor in this space publishes the same thing about licensing:
nothing.** Tanzil states its translations are non-commercial only; quranenc.com,
qul.tarteel.ai and the mirrors show no terms at all. So the only texts whose
status can be established independently of whoever is hosting them are the ones
that are **public domain by age**, and that is the standard applied here.

Tafsir al-Jalalayn was written by Jalal al-Din al-Mahalli (d. 1459) and finished
by Jalal al-Din al-Suyuti (d. 1505). It has been in the public domain everywhere
for four centuries longer than copyright has existed. It is also the tafsir
actually built for this screen: a terse gloss written to be read *beside* the
verse, quoting the words it explains between ﴿ ﴾ ornaments, which is why nearly
every Quran application carries it.

**English is deliberately absent.** The classical Arabic is free; every English
translation of it belongs to its modern translator — Feras Hamza's is © 2007 the
Royal Aal al-Bayt Institute, Aisha Bewley's is her own. Nothing English gets
bundled until that is settled, which is the same rule `Resources/Corpus/README.md`
records for the Quran's translations.

## 226 verses have no note, and that is the work rather than a gap

Al-Jalalayn says nothing about 226 of the 6,236 verses — they are the plain
formulas whose meaning needs no gloss, and the two Jalals passed over them. This
was checked rather than assumed: the independently-sourced *English* edition of
the same tafsir carries, for exactly those verses, the verse restated with no
commentary added. So the silence is the commentary's, not the mirror's.

Those verses get no row. The app is expected to say that this tafsir has no note
on this verse — not to show an empty screen, and not to borrow the note from the
verse above, which would put a gloss of one verse under another.

Usage:
    python3 Tools/CorpusBuilder/build_tafsir_db.py           # downloads upstream
    python3 Tools/CorpusBuilder/build_tafsir_db.py --source path/to/edition/
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "tafsir.sqlite"
QURAN_DB = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "quran.sqlite"

# Bumped whenever the shape below changes.
# 1: edition + tafsir, Arabic al-Jalalayn only.
SCHEMA_VERSION = 1

SURAH_COUNT = 114
VERSE_COUNT = 6236
# How many of those the two Jalals passed over. Pinned, because a change in it is
# a change in the commentary and should be looked at rather than absorbed.
UNCOMMENTED_COUNT = 226

# A mirror, not the source: the text is `spa5k/tafsir_api`'s copy of what
# quran.com and altafsir.com carry. That indirection is acceptable *here and only
# here* because the underlying work is five centuries old — there is no licence
# to inherit from the host, only a transcription to check. Pinned by digest below
# so the transcription cannot change under the app without a build failure.
SOURCE_URL = (
    "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/ar-tafsir-al-jalalayn"
)

TEXT_DIGEST = "15f89b2781e2b8e804d2c6dc837ef892ea206c4f6f91eed9b7daf5af69beedc2"

EDITION = {
    "id": "jalalayn",
    "name_ar": "تفسير الجلالين",
    "name_en": "Tafsir al-Jalalayn",
    "author_ar": "جلال الدين المحلي وجلال الدين السيوطي",
    "author_en": "Jalal al-Din al-Mahalli and Jalal al-Din al-Suyuti",
    "language": "ar",
    # Carried in the database rather than only in this script, so a copy of the
    # file on its own still says why it may be redistributed.
    "licence": "Public domain — completed 1505 CE (911 AH)",
    "source_url": SOURCE_URL,
}


SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};

CREATE TABLE edition (
    id          TEXT PRIMARY KEY,
    name_ar     TEXT NOT NULL,
    name_en     TEXT NOT NULL,
    author_ar   TEXT NOT NULL,
    author_en   TEXT NOT NULL,
    -- Which language the *notes* are in, which is not the language of the app.
    -- An Arabic tafsir is all this project can ship today; see the module note.
    language    TEXT NOT NULL CHECK (language IN ('ar', 'en')),
    -- Why this may be redistributed, in words, travelling with the data.
    licence     TEXT NOT NULL,
    source_url  TEXT NOT NULL
);

CREATE TABLE tafsir (
    edition_id  TEXT    NOT NULL REFERENCES edition(id),
    surah_id    INTEGER NOT NULL CHECK (surah_id BETWEEN 1 AND {SURAH_COUNT}),
    number      INTEGER NOT NULL CHECK (number > 0),
    text        TEXT    NOT NULL CHECK (length(text) > 0),
    -- A verse the edition passes over has no row at all, rather than a row
    -- holding an empty string. "There is no note" is a fact about the
    -- commentary; an empty string would be a note that says nothing.
    PRIMARY KEY (edition_id, surah_id, number)
);
"""


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read().decode("utf-8")


def read_edition(source: Path | None) -> dict[tuple[int, int], str]:
    """The notes, keyed by verse — from a local directory or from the mirror.

    One file per chapter rather than one per verse: the same data is published
    both ways, and 114 requests is neighbourly where 6,236 is not.
    """
    notes: dict[tuple[int, int], str] = {}

    for surah in range(1, SURAH_COUNT + 1):
        if source:
            raw = (source / f"{surah}.json").read_text(encoding="utf-8")
        else:
            raw = fetch(f"{SOURCE_URL}/{surah}.json")

        for item in json.loads(raw):
            text = item["text"].strip()
            if not text:
                continue
            notes[(int(item["surah"]), int(item["ayah"]))] = text

    return notes


def check(notes: dict[tuple[int, int], str]) -> None:
    """Everything that would be a wrong note under a verse rather than an error."""
    if not QURAN_DB.exists():
        raise SystemExit(
            f"{QURAN_DB.name} is not built yet — the tafsir is checked against the "
            "verses it comments on, so build the Quran database first."
        )

    connection = sqlite3.connect(f"file:{QURAN_DB}?mode=ro", uri=True)
    try:
        verses = {
            (surah, number)
            for surah, number in connection.execute(
                "SELECT surah_id, number FROM verse"
            )
        }
    finally:
        connection.close()

    if len(verses) != VERSE_COUNT:
        raise SystemExit(f"{QURAN_DB.name} has {len(verses)} verses, expected {VERSE_COUNT}")

    # A note on a verse that does not exist is the loudest possible sign that the
    # edition is numbered differently from the mushaf this app ships — which would
    # silently put every note under the wrong verse from that point on.
    stray = sorted(set(notes) - verses)
    if stray:
        raise SystemExit(
            f"the edition has notes on {len(stray)} verses the mushaf does not "
            f"have, starting at {stray[0][0]}:{stray[0][1]} — its verse numbering "
            "is not Tanzil's, and nothing may be joined on it."
        )

    uncommented = len(verses) - len(notes)
    if uncommented != UNCOMMENTED_COUNT:
        raise SystemExit(
            f"the edition passes over {uncommented} verses; {UNCOMMENTED_COUNT} were "
            "expected. Upstream has changed what the commentary covers — look at it "
            "before re-pinning, and see the module docstring for why the count is "
            "pinned at all."
        )

    digest = hashlib.sha256(
        "\n".join(f"{s}|{n}|{t}" for (s, n), t in sorted(notes.items())).encode("utf-8")
    ).hexdigest()
    if digest != TEXT_DIGEST:
        raise SystemExit(
            "the tafsir text has changed upstream.\n"
            f"  expected {TEXT_DIGEST}\n"
            f"  got      {digest}\n"
            "This is a mirror of a five-century-old work; a diff here is a change "
            "in the transcription, not in the tafsir. Read it before re-pinning."
        )


def build(notes: dict[tuple[int, int], str], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        connection.execute(
            """
            INSERT INTO edition (
                id, name_ar, name_en, author_ar, author_en, language, licence, source_url
            ) VALUES (
                :id, :name_ar, :name_en, :author_ar, :author_en, :language, :licence, :source_url
            )
            """,
            EDITION,
        )
        connection.executemany(
            "INSERT INTO tafsir (edition_id, surah_id, number, text) VALUES (?, ?, ?, ?)",
            [
                (EDITION["id"], surah, number, text)
                for (surah, number), text in sorted(notes.items())
            ],
        )
        connection.commit()

        # Read-only from here on, so there is no reason to ship free pages.
        connection.execute("VACUUM")
        connection.commit()
        report(connection, output)
    finally:
        connection.close()


def report(connection: sqlite3.Connection, output: Path) -> None:
    editions = connection.execute("SELECT count(*) FROM edition").fetchone()[0]
    notes = connection.execute("SELECT count(*) FROM tafsir").fetchone()[0]
    covered = connection.execute(
        "SELECT count(DISTINCT surah_id) FROM tafsir"
    ).fetchone()[0]

    try:
        shown = output.relative_to(REPO_ROOT)
    except ValueError:
        shown = output

    print(f"wrote {shown} ({output.stat().st_size} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")
    print(f"  {editions} edition, {notes} notes across {covered} chapters")
    print(f"  {VERSE_COUNT - notes} verses the commentary passes over")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        help="a local directory of per-chapter JSON, instead of the mirror",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    notes = read_edition(arguments.source)
    check(notes)
    build(notes, arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
