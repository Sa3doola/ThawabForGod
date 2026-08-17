# Corpus

Read-only reference data that ships inside the app, as SQLite. Nothing in here is
ever written to at runtime — the databases are opened read-only, and anything the
*user* changes (bookmarks, counts, progress) belongs in `Core/Persistence`'s
SwiftData store instead.

Later content features — Tasbih, the 99 Names, Quran — get their own tables (or
their own file) read through the same `CorpusDatabaseProviding` infrastructure.

---

## ⚠️ The adhkar text is NOT yet verified

**`adhkar.sqlite` must not ship in V1 until someone has checked it against a
printed copy of Hisn al-Muslim.** It is third-party data that has been reshaped by
a script; no scholar and no maintainer of this project has read it line by line.

What needs a pass, per dhikr:

- the Arabic text, including its diacritics
- the repeat count
- the source citation — the book, and the hadith or page number within it
- the grading of the narration, where the citation gives one
- the English translation and transliteration

Until that has happened, the app must not present this content as verified, and
this note must not be deleted. The citation is stored per dhikr and shown in the
reading view precisely so a reader can check it themselves rather than take the
app's word for it.

## Source

[Seen-Arabic/Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB),
MIT licensed, © 2024 Seen Arabic. Arabic and English, 34 adhkar.

Its scope is exactly what its name says: morning and evening. The other
categories one would expect in Hisn al-Muslim — after prayer, before sleep, on
waking, entering and leaving the home, meals — are **not** in this data set, and
so are not in the app. `AdhkarCategory` deliberately carries only the two
categories that have rows behind them; a category with no adhkar in it is a row
the user taps to reach an empty screen.

Adding the rest is a data change, not a code change: add a row to `category`, add
its adhkar, and add the `dhikr_category` rows joining them. `AdhkarCategory` gains
a case with the matching raw value and the feature picks it up.

## Rebuilding `adhkar.sqlite`

```bash
python3 Tools/CorpusBuilder/build_adhkar_db.py
```

That downloads the two upstream JSON files and regenerates the database in place.
Pass `--source-dir path/to/checkout` to build from a local clone instead — which
is also how to build from a pinned upstream revision rather than `HEAD`.

The script is the only thing that writes this file. **Do not edit rows by hand**:
a hand-edited database cannot be reproduced, and the next rebuild silently throws
the edit away. Corrections belong either upstream or in the script.

### Why we generate our own rather than ship theirs

Upstream publishes one SQLite per language — `ar.sqlite` and `en.sqlite` — each a
flat dump of its own JSON file. Two things make that the wrong shape for the app:

- **One row per dhikr, not per language.** The Arabic text is shown to every
  reader whatever their language; only the translation, transliteration, citation
  and virtue differ. Two parallel databases would mean opening both and joining
  them at runtime to render a single card.
- **A dhikr can belong to more than one category.** Upstream encodes this as a
  `type` integer (0 = both morning and evening, 1 = morning only, 2 = evening
  only), which stops working the moment a third category exists. The build step
  expands it into a `dhikr_category` join table, so 16 of the 34 adhkar simply
  have two rows in it.

### Schema

| table            | holds                                                                |
| ---------------- | -------------------------------------------------------------------- |
| `category`       | `id` (matches `AdhkarCategory`'s raw value), `sort_order`             |
| `dhikr`          | the Arabic text, both citations, both virtues, translation, transliteration, repeat count |
| `dhikr_category` | which adhkar belong to which category, and in what order              |

`PRAGMA user_version` is the schema version, and is `1`. Bump it in the build
script when the shape changes, so a reader can tell the two apart.

### The citation is prose, not a structured reference

`reference_ar` / `reference_en` hold the citation exactly as upstream wrote it —
`Abu Dawood, No. 5074, and Ibn Majah, No. 3871. See: Sahih Ibn Majah, 2/332.` —
rather than a parsed book-and-number pair. Most citations name several books,
several numbers, and a grading, so splitting them into one book and one number
would throw information away and invent precision the source does not have. The
reading view prints the line as written.
