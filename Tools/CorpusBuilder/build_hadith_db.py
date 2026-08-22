#!/usr/bin/env python3
"""Build the bundled hadith database.

Writes `ThawabForGod/Resources/Corpus/hadith.sqlite` — the two Sahihs, in Arabic:

- `collection` — one row per book, with its compiler and the reason this project
                 believes it may ship it.
- `book`       — the kitab divisions each collection is organised into.
- `hadith`     — the narrations, keyed by collection and reference number.
- `source`     — where the text came from and under what terms, travelling
                 inside the file rather than only in the README.

Its own file rather than more tables in `corpus.sqlite`, for the fourth time the
same argument holds: a different upstream, a different licence, and a size that
grows with every collection added. `CorpusDatabase` is constructed with a
resource name and knows nothing about what is inside it, so a fourth file costs
nothing.

## Why only Bukhari and Muslim, and why no gradings

The nine books are not in the same position as each other, and the difference is
not a matter of taste.

**A hadith's grading is what tells a reader whether to act on it**, and Sunan Abi
Dawud, Jami' at-Tirmidhi, Sunan an-Nasa'i and Sunan Ibn Majah were compiled to
*include* weak narrations, not to exclude them. Showing one of those without its
grading would put a text in front of a reader with the app's implicit assurance
behind it and nothing to say how sound it is — the single worst thing this
feature could do.

So the gradings would have to ship too, and they cannot. Every grader in the
freely-published data is modern: al-Albani (d. 1999), Shu'ayb al-Arna'ut
(d. 2016), Zubair Ali Zai (d. 2013), Muhammad Muhyi al-Din Abd al-Hamid
(d. 1972). Their judgements are 20th-century scholarship, in copyright
everywhere, and no mirror that republishes them holds the rights to license
them on.

**Bukhari and Muslim are the exception, and structurally so.** Their compilers
graded the contents by deciding what went in; "sahih" is the title of the book
rather than a modern annotation on top of it. That is a fact about which
collection a narration is in, which needs nobody's permission to state, and it
is why these two can ship complete and alone while the rest wait for a licence
that may never come.

## Arabic only, deliberately

The same wall the tafsir slice hit. The Arabic of both Sahihs has been in the
public domain for eleven centuries. Every English translation of them is modern
and owned — Muhsin Khan's Bukhari and the Siddiqui and Khattab renderings of
Muslim are all published, in-copyright work, whatever a mirror's own repository
licence happens to say about the code beside them.

So an English-reading user gets the book and chapter names and nothing else from
this slice. That is a known gap, recorded here and in
`Resources/Corpus/README.md`, and not a bug.

## Two sources, because the second one is the check

The text and the reference numbers come from
[fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api), which is
released under the Unlicense. That dedication covers what its author can give
away and nothing more, which is exactly why the underlying work has to be public
domain by age for any of this to be shippable — the same reasoning
`build_tafsir_db.py` sets out at greater length.

It is used because **it carries the numbers a reader can cite.** Its last hadith
of Bukhari is 7563, the standard total; the other widely-mirrored data set,
[AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json), numbers the
same narration 7277 because it indexes sequentially and merges what sunnah.com
splits. A citation is the whole point of shipping a reference number, so the
edition that gets them right is the one the corpus is built from.

The second source is still downloaded, and used for two things:

1. **It is the cross-check on the text.** 7,266 of its 7,277 Bukhari narrations
   and 7,278 of its 7,459 from Muslim fold word-for-word onto this corpus's. The
   shortfall is not disagreement: this corpus is built from an edition that
   leaves 203 of Muslim's reference numbers empty, so those narrations are here
   under a neighbouring number rather than absent. Where both sources carry a
   narration, they carry the same words. That comparison runs on every build,
   and a drop below the pinned floor fails it.
2. **It supplies the Arabic book titles**, which the first source publishes in
   English only. The two agree on all 97 of Bukhari's kitab titles and all 57 of
   Muslim's, exactly, which is what makes joining the Arabic ones onto the
   division numbers safe rather than hopeful — and the build asserts it rather
   than trusting it. It also carries the kitab each narration belongs to, which
   the first source publishes wrongly; see `assign_books`.

## Empty entries are continuation numbers, not missing text

sunnah.com gives one narration several reference numbers where the classical
editions group them — Bukhari 5709 carries 5709 through 5712 — and the mirror
represents that as the text on the first number and empty entries on the rest.
Nine Bukhari entries and 203 of Muslim's are empty for this reason.

They are not dropped and they are not shown blank. Each one extends the
preceding hadith's `number_last`, so the row says it covers 5709–5712 and a
reader who came looking for 5711 finds it where it actually is. The handful with
no preceding narration to extend — the opening paragraphs of Muslim's
introduction, which sunnah.com numbers but carries no Arabic for — are dropped,
and the count is pinned below so that a change in it has to be looked at.

## One text, not two

`build_quran_db.py` downloads a second copy of the Quran because Uthmani
orthography spells ٱلسَّمَٰوَٰتِ, whose letters alone are `السموت` — a word no reader
will ever type — so the search index had to be folded from a different text.
**That does not apply here.** The Sahihs are printed in ordinary vowelled
Arabic: strip the marks from ٱلْأَنْصَارِيُّ and `الأنصاري` is left, which is what a
reader types. So the search index is folded from the displayed text itself, and
the two cannot drift apart because there is only one of them.

The folded form is also not *stored*: it goes straight into a contentless FTS5
index and nowhere else, which is nine megabytes this file does not carry. See
the note on `hadith_fts` in the schema.

## Nothing here has been read against a printed edition

Two mirrors agreeing is evidence that neither transcription drifted, not that
the transcription was right to begin with. See `Resources/Corpus/README.md`.

Usage:
    python3 Tools/CorpusBuilder/build_hadith_db.py            # downloads upstream
    python3 Tools/CorpusBuilder/build_hadith_db.py --source path/to/json/
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import unicodedata
import urllib.request
from pathlib import Path
from typing import NamedTuple

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "ThawabForGod" / "Resources" / "Corpus" / "hadith.sqlite"

# Bumped whenever the shape below changes.
# 1: collection + book + hadith + source, the two Sahihs in Arabic, with an
#    FTS5 index over the folded text.
SCHEMA_VERSION = 1

TEXT_BASE = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions"
CHECK_BASE = (
    "https://raw.githubusercontent.com/AhmedBaset/hadith-json/main/db/by_book/the_9_books"
)


class Collection(NamedTuple):
    """A book of hadith, and everything the corpus says about it that is not text."""

    id: str
    ordinal: int
    name_ar: str
    name_en: str
    author_ar: str
    author_en: str
    licence: str

    # What the build refuses to finish without. Each is a fact about the
    # published collection rather than about the mirror, so a mismatch means the
    # mirror changed and somebody should read the diff before the app ships it.
    last_number: int
    book_count: int
    #: Entries the mirror leaves empty because they continue the hadith before.
    continuation_count: int
    #: Entries it leaves empty with nothing before them to continue.
    orphan_count: int
    #: Narrations whose kitab is inherited from the one before — see `assign_books`.
    carried_count: int
    #: How many of the cross-check's narrations must fold onto one of ours.
    agreement_floor: int
    #: Narrations carrying a Latin letter — see `check_text`. Should be zero.
    latin_count: int


COLLECTIONS = (
    Collection(
        id="bukhari",
        ordinal=1,
        name_ar="صحيح البخاري",
        name_en="Sahih al-Bukhari",
        author_ar="الإمام محمد بن إسماعيل البخاري",
        author_en="Imam Muhammad ibn Isma'il al-Bukhari",
        licence="Public domain — compiled by 870 CE (256 AH)",
        last_number=7563,
        book_count=97,
        continuation_count=9,
        orphan_count=0,
        carried_count=27,
        agreement_floor=7266,
        latin_count=1,
    ),
    Collection(
        id="muslim",
        ordinal=2,
        name_ar="صحيح مسلم",
        name_en="Sahih Muslim",
        author_ar="الإمام مسلم بن الحجاج القشيري النيسابوري",
        author_en="Imam Muslim ibn al-Hajjaj al-Naysaburi",
        licence="Public domain — compiled by 875 CE (261 AH)",
        last_number=7563,
        book_count=57,
        continuation_count=201,
        orphan_count=2,
        carried_count=17,
        agreement_floor=7278,
        latin_count=0,
    ),
)

SOURCES = (
    (
        "fawazahmed0-hadith-api",
        "fawazahmed0/hadith-api — Arabic editions",
        "https://github.com/fawazahmed0/hadith-api",
        "Unlicense (the compilation); the narrations themselves are public domain by age",
        "The Arabic text and the reference numbers in this file come from the "
        "`ara-bukhari` and `ara-muslim` editions of fawazahmed0/hadith-api, which "
        "is dedicated to the public domain under the Unlicense. The narrations it "
        "carries are the two Sahihs, compiled in the 9th century CE and in the "
        "public domain everywhere on their own account.",
    ),
    (
        "ahmedbaset-hadith-json",
        "AhmedBaset/hadith-json — Arabic book titles, and the text cross-check",
        "https://github.com/AhmedBaset/hadith-json",
        "No licence stated; used only for classical Arabic titles and for verification",
        "The Arabic titles of the kitab divisions come from AhmedBaset/hadith-json, "
        "which also serves as the independent check on the narrations: the two "
        "sources agree character-for-character, below the search folding, on every "
        "narration they both carry. Nothing authored by that project — in "
        "particular none of its English translations — is reproduced here.",
    ),
)


SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};

CREATE TABLE collection (
    id          TEXT PRIMARY KEY,
    -- The order the two Sahihs are conventionally listed in, which is not
    -- alphabetical in either language and so cannot be derived from the names.
    ordinal     INTEGER NOT NULL UNIQUE,
    name_ar     TEXT NOT NULL,
    name_en     TEXT NOT NULL,
    author_ar   TEXT NOT NULL,
    author_en   TEXT NOT NULL,
    -- Why this may be redistributed, in words, travelling with the data.
    licence     TEXT NOT NULL
);

CREATE TABLE book (
    collection_id  TEXT    NOT NULL REFERENCES collection(id),
    -- The kitab number within its collection. Not globally unique, and zero in
    -- Muslim, whose introduction is numbered 0 by the convention
    -- this edition follows.
    number         INTEGER NOT NULL CHECK (number >= 0),
    title_ar       TEXT    NOT NULL CHECK (length(title_ar) > 0),
    title_en       TEXT    NOT NULL CHECK (length(title_en) > 0),
    hadith_count   INTEGER NOT NULL CHECK (hadith_count > 0),
    PRIMARY KEY (collection_id, number)
);

CREATE TABLE hadith (
    -- An explicit rowid, because the FTS5 index below is keyed on it.
    id              INTEGER PRIMARY KEY,
    collection_id   TEXT    NOT NULL REFERENCES collection(id),
    book_number     INTEGER NOT NULL,
    -- The reference number a reader would cite: "Sahih al-Bukhari 5709".
    number          INTEGER NOT NULL CHECK (number > 0),
    -- Which narration under that number this is, and 0 for almost all of them.
    -- Sahih al-Bukhari prints two hadith under a single reference number in 26
    -- places; both are cited as that number, so the number cannot tell them
    -- apart and something has to. It orders them and nothing else — no screen
    -- shows it.
    part            INTEGER NOT NULL DEFAULT 0 CHECK (part >= 0),
    -- The last number this same narration is cited under, which is `number`
    -- again for all but a few hundred. sunnah.com splits into several numbered
    -- entries what the printed editions group as one hadith; the row covers the
    -- whole span so that looking up any number in it lands on the text.
    number_last     INTEGER NOT NULL CHECK (number_last >= number),
    text            TEXT    NOT NULL CHECK (length(text) > 0),
    FOREIGN KEY (collection_id, book_number) REFERENCES book(collection_id, number),
    UNIQUE (collection_id, number, part)
);

-- Reading a kitab straight through is the only way this table is ever scanned.
CREATE INDEX hadith_by_book ON hadith (collection_id, book_number, number, part);

-- Answering "show me Sahih al-Bukhari 5709", which is what a citation is for.
CREATE INDEX hadith_by_number ON hadith (collection_id, number, number_last);

CREATE TABLE source (
    id        TEXT PRIMARY KEY,
    name      TEXT NOT NULL,
    url       TEXT NOT NULL,
    licence   TEXT NOT NULL,
    notice    TEXT NOT NULL
);

-- A *contentless* index, which is where this file departs from `quran.sqlite`
-- and is worth the paragraph.
--
-- The Quran keeps a `text_normalized` column and points an external-content
-- index at it. That column is never read by anything: it exists so FTS5 has
-- something to index, and the folded text is a second copy of the corpus. For
-- 6,236 verses that copy is small enough not to matter. For 14,940 narrations
-- it is nine megabytes in the app bundle, to store a form of the text no screen
-- will ever show.
--
-- So the folded text is handed to FTS5 and nowhere else. A match comes back as
-- a rowid, which is `hadith.id`, and the narration is read from `hadith`. What
-- is given up is `snippet()` and `highlight()` — and neither was usable anyway,
-- for the reason the Quran's search notes: the index is over the folded text,
-- so a match's offsets do not correspond to positions in the vowelled text
-- drawn on screen.
CREATE VIRTUAL TABLE hadith_fts USING fts5(
    text_normalized,
    content = ''
);
"""


# MARK: The folding

# Every combining mark is dropped by `skeleton`; these are the letters that
# survive but are written more than one way. Mirrors `LETTER_FOLDING` in
# `build_quran_db.py` and `QuranSearchQuery.letterFolding` in the app.
LETTER_FOLDING = str.maketrans({
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",   # every hamza-bearing alef
    "ة": "ه",                                  # ta marbuta, which readers type as ha
    "ى": "ي",                                  # alef maqsura
    "ؤ": "و",
    "ئ": "ي",
    "ـ": "",                                   # tatweel, a typographic stretch
})


def skeleton(text: str) -> str:
    """The letters alone, with every combining mark dropped."""
    text = unicodedata.normalize("NFC", text)
    return "".join(c for c in text if not unicodedata.combining(c))


#: Everything that is not a letter or a digit, which is where words end.
BOUNDARY = re.compile(r"[^\w]+|_+", re.UNICODE)


def normalize(text: str) -> str:
    """The form search matches against: no diacritics, one spelling per letter, words only.

    One step further than the Quran's `normalize`, and for a reason particular to
    this corpus. The mushaf carries no punctuation, so folding its verses leaves
    words alone; hadith are printed with commas and colons all through the isnad,
    and the two mirrors of them do not agree on where those go or on how much
    space surrounds them. Dropping them here costs nothing — FTS5's `unicode61`
    tokenizer and `QuranSearchQuery`'s folding both split on exactly these
    characters anyway — and it is what lets the two sources be compared as text
    rather than as typography.
    """
    folded = skeleton(text).translate(LETTER_FOLDING)
    return " ".join(BOUNDARY.sub(" ", folded).split())


# MARK: Reading the sources


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=180) as response:
        return response.read().decode("utf-8")


def read_json(source: Path | None, name: str, url: str) -> dict:
    if source:
        return json.loads((source / name).read_text(encoding="utf-8"))
    return json.loads(fetch(url))


class Narration(NamedTuple):
    """One row of `hadith`, before it has an id."""

    book_number: int
    number: int
    part: int
    number_last: int
    text: str


class Reading(NamedTuple):
    """Everything one collection contributes to the database."""

    collection: Collection
    books: list[tuple[int, str, str, int]]      # number, title_ar, title_en, count
    narrations: list[Narration]


def assign_books(
    collection: Collection, cross_check: dict, narrations: list[Narration]
) -> list[Narration]:
    """Which kitab each narration belongs to, taken from the second source.

    Neither of the two obvious answers works. Each entry carries its own
    `reference: {book, hadith}`, but the mirror leaves it `{0, 0}` on hundreds of
    real narrations. The edition also publishes a first/last reference number per
    section — and for Sahih Muslim those ranges are visibly wrong: kitab 15 is
    said to end at 3397 and kitab 16 to start at 388, which cannot both be true
    of a book read front to back. Placing narrations by those ranges would hang
    the wrong kitab name over a fifth of Sahih Muslim.

    So the divisions come from the cross-check, which carries a kitab on every
    narration, and the join is on the folded text. Most narrations match
    outright; the rest inherit the kitab of the last one that did, which is only
    sound because both sources list the collection in the same order — and *that*
    is what the non-decreasing check below actually tests. A source reordered
    against ours trips it rather than silently scattering narrations across
    kitabs.
    """
    kitab_of: dict[str, int] = {}
    ambiguous: set[str] = set()
    for entry in cross_check["hadiths"]:
        folded = normalize(entry["arabic"])
        if folded in kitab_of and kitab_of[folded] != int(entry["chapterId"]):
            # The same words filed under two kitab — rare, and no basis to choose.
            ambiguous.add(folded)
        kitab_of[folded] = int(entry["chapterId"])

    placed: list[Narration] = []
    carried = 0
    current: int | None = None

    for narration in narrations:
        folded = normalize(narration.text)
        matched = None if folded in ambiguous else kitab_of.get(folded)

        if matched is None:
            if current is None:
                raise SystemExit(
                    f"{collection.id} {narration.number} opens the collection and is "
                    "in neither source's kitab — there is nothing to place it by."
                )
            carried += 1
            matched = current
        elif current is not None and matched < current:
            raise SystemExit(
                f"{collection.id} {narration.number} is in kitab {matched}, after a "
                f"narration in kitab {current}. The two sources no longer agree on "
                "the order of the collection, so nothing may be carried forward."
            )

        current = matched
        placed.append(narration._replace(book_number=matched))

    if carried != collection.carried_count:
        raise SystemExit(
            f"{collection.id}: {carried} narrations took their kitab from the "
            f"narration before them, and {collection.carried_count} did before. "
            "Upstream has changed which narrations the two sources share."
        )

    return placed


def read_collection(collection: Collection, source: Path | None) -> Reading:
    text_edition = read_json(
        source, f"ara-{collection.id}.json", f"{TEXT_BASE}/ara-{collection.id}.json"
    )
    cross_check = read_json(
        source, f"{collection.id}.json", f"{CHECK_BASE}/{collection.id}.json"
    )

    metadata = text_edition["metadata"]
    # Sorted as numbers rather than by array order, and as *real* numbers: 26 of
    # Bukhari's entries arrive fractional (402.2 after 402), which is how this
    # edition writes the second narration printed under one reference number.
    entries = sorted(text_edition["hadiths"], key=lambda h: float(h["hadithnumber"]))

    if entries[-1]["hadithnumber"] != collection.last_number:
        raise SystemExit(
            f"{collection.id} ends at {entries[-1]['hadithnumber']}, expected "
            f"{collection.last_number}. The reference numbering is the whole reason "
            "this edition was chosen; a change in it must be read, not absorbed."
        )

    # MARK: The narrations, with the grouped entries folded into their own

    narrations: list[Narration] = []
    parts: dict[int, int] = {}
    continuations = orphans = 0

    for entry in entries:
        number = int(entry["hadithnumber"])
        text = entry["text"].strip()

        if not text:
            # A reference number the printed editions do not give a hadith of its
            # own. It continues the narration before it — which, because the
            # entries are in reference order, is the one it belongs to.
            if narrations:
                previous = narrations[-1]
                narrations[-1] = previous._replace(
                    number_last=max(previous.number_last, number)
                )
                continuations += 1
            else:
                orphans += 1
            continue

        # The kitab is filled in below, once both sources are in hand.
        narrations.append(
            Narration(
                book_number=-1,
                number=number,
                part=parts.get(number, 0),
                number_last=number,
                text=text,
            )
        )
        parts[number] = parts.get(number, 0) + 1

    if continuations != collection.continuation_count:
        raise SystemExit(
            f"{collection.id} has {continuations} continuation entries, expected "
            f"{collection.continuation_count} — upstream has regrouped narrations."
        )
    if orphans != collection.orphan_count:
        raise SystemExit(
            f"{collection.id} has {orphans} numbered entries with no text and "
            f"nothing to attach to, expected {collection.orphan_count}. Each one is "
            "a reference number the app cannot answer; look before re-pinning."
        )

    narrations = assign_books(collection, cross_check, narrations)
    books = read_books(collection, metadata, cross_check, narrations)
    check_text(collection, narrations)
    check_against(collection, cross_check, narrations)
    return Reading(collection, books, narrations)


def read_books(
    collection: Collection,
    metadata: dict,
    cross_check: dict,
    narrations: list[Narration],
) -> list[tuple[int, str, str, int]]:
    """The kitab divisions — English titles from one source, Arabic from the other.

    The join is on the section number, and it is only safe because the two sources
    agree on every English title exactly. That agreement is asserted here rather
    than assumed: a silent drift would hang the wrong Arabic name over a kitab,
    which reads as an error in the corpus rather than in a script.
    """
    arabic = {int(c["id"]): c for c in cross_check["chapters"]}
    counts: dict[int, int] = {}
    for narration in narrations:
        counts[narration.book_number] = counts.get(narration.book_number, 0) + 1

    books: list[tuple[int, str, str, int]] = []
    for key, title_en in metadata["sections"].items():
        number = int(key)
        title_en = title_en.strip()
        if not title_en:
            # Bukhari's section 0 is an empty placeholder in this edition, and has
            # no kitab behind it in either source.
            continue

        theirs = arabic.get(number)
        if theirs is None:
            raise SystemExit(
                f"{collection.id} kitab {number} ({title_en!r}) has no Arabic title"
            )
        if theirs["english"].strip().casefold() != title_en.casefold():
            raise SystemExit(
                f"{collection.id} kitab {number}: the two sources name it "
                f"{title_en!r} and {theirs['english']!r}. The divisions no longer "
                "line up, so the Arabic titles must not be joined on the number."
            )

        books.append((number, theirs["arabic"].strip(), title_en, counts.get(number, 0)))

    if len(books) != collection.book_count:
        raise SystemExit(
            f"{collection.id} has {len(books)} kitab divisions, expected "
            f"{collection.book_count}"
        )

    empty = [number for number, _, _, count in books if count == 0]
    if empty:
        raise SystemExit(
            f"{collection.id} kitab {empty} have no narrations in them — a row the "
            "reader taps to reach an empty screen."
        )

    return books


LATIN = re.compile(r"[A-Za-z]")


def check_text(collection: Collection, narrations: list[Narration]) -> None:
    """That nothing English got into the narrations, and that the one exception is still one.

    **This is the licensing rule, enforced.** The two Sahihs are public domain by age; every
    English translation of them belongs to a living translator and none is licensed to this
    project. A Latin letter in a narration would mean a translated column had been read by
    mistake, which is the one packaging error here that would ship somebody's copyrighted work.

    Sahih al-Bukhari 4757 is the standing exception and it is not a translation: it carries a
    stray `v` where the upstream transcription lost an opening `﴿` before a quoted verse — one
    character in fifteen thousand narrations. It is left exactly as it arrived, because this file
    does not edit the text it ships, and pinned here so that a *second* one is loud.
    """
    offenders = [n for n in narrations if LATIN.search(n.text)]

    if len(offenders) != collection.latin_count:
        numbers = ", ".join(str(n.number) for n in offenders[:10])
        raise SystemExit(
            f"{collection.id}: {len(offenders)} narrations carry a Latin letter and "
            f"{collection.latin_count} did before — at {numbers}. Either the transcription has "
            "changed upstream, or a translated column is being read. Read them before re-pinning."
        )


def check_against(
    collection: Collection, cross_check: dict, narrations: list[Narration]
) -> None:
    """How much of the second source folds onto the first.

    Not a digest of either, deliberately. Two mirrors of an eleven-century-old
    text will differ in whitespace and in where they put a hamza forever; what
    matters is whether they are carrying the same narrations, and folding both
    the way search folds them is the test that answers that and ignores the rest.
    """
    ours = {normalize(n.text) for n in narrations}
    agreed = sum(1 for h in cross_check["hadiths"] if normalize(h["arabic"]) in ours)

    if agreed < collection.agreement_floor:
        raise SystemExit(
            f"{collection.id}: only {agreed} of the cross-check's "
            f"{len(cross_check['hadiths'])} narrations fold onto this corpus, and "
            f"{collection.agreement_floor} did before. One of the two mirrors has "
            "changed its text. Read the diff before re-pinning."
        )


# MARK: Writing


def build(readings: list[Reading], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)

        connection.executemany(
            "INSERT INTO collection (id, ordinal, name_ar, name_en, author_ar, "
            "author_en, licence) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [
                (c.id, c.ordinal, c.name_ar, c.name_en, c.author_ar, c.author_en, c.licence)
                for c in (reading.collection for reading in readings)
            ],
        )
        connection.executemany(
            "INSERT INTO source (id, name, url, licence, notice) VALUES (?, ?, ?, ?, ?)",
            SOURCES,
        )

        for reading in readings:
            connection.executemany(
                "INSERT INTO book (collection_id, number, title_ar, title_en, "
                "hadith_count) VALUES (?, ?, ?, ?, ?)",
                [(reading.collection.id, *book) for book in reading.books],
            )
            connection.executemany(
                "INSERT INTO hadith (collection_id, book_number, number, part, "
                "number_last, text) VALUES (?, ?, ?, ?, ?, ?)",
                [
                    (
                        reading.collection.id,
                        n.book_number,
                        n.number,
                        n.part,
                        n.number_last,
                        n.text,
                    )
                    for n in reading.narrations
                ],
            )

        # Fed narration by narration rather than from a SELECT: the index is
        # contentless, so the folded text exists nowhere to select it from.
        connection.executemany(
            "INSERT INTO hadith_fts (rowid, text_normalized) VALUES (?, ?)",
            [
                (id, normalize(text))
                for id, text in connection.execute(
                    "SELECT id, text FROM hadith ORDER BY id"
                ).fetchall()
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
    try:
        shown = output.relative_to(REPO_ROOT)
    except ValueError:
        shown = output

    print(f"wrote {shown} ({output.stat().st_size:,} bytes)")
    print(f"  schema version {SCHEMA_VERSION}")

    for id, name_en, books, count, grouped in connection.execute(
        """
        SELECT c.id, c.name_en,
               (SELECT count(*) FROM book WHERE collection_id = c.id),
               (SELECT count(*) FROM hadith WHERE collection_id = c.id),
               (SELECT count(*) FROM hadith
                 WHERE collection_id = c.id AND number_last > number)
          FROM collection c ORDER BY c.ordinal
        """
    ):
        print(f"  {name_en}: {count:,} narrations in {books} kitab, {grouped} grouped")

    indexed = connection.execute("SELECT count(*) FROM hadith_fts").fetchone()[0]
    print(f"  {indexed:,} narrations indexed for search")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        help="a local directory of the upstream JSON, instead of downloading it",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    readings = [read_collection(c, arguments.source) for c in COLLECTIONS]
    build(readings, arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
