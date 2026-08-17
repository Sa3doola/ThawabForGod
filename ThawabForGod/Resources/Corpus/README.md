# Corpus

Read-only reference data that ships inside the app, as SQLite. Nothing in here is
ever written to at runtime — the databases are opened read-only, and anything the
*user* changes (bookmarks, counts, progress) belongs in `Core/Persistence`'s
SwiftData store instead.

`corpus.sqlite` holds one table set per feature — the adhkar, the tasbih presets
and the 99 names today; the Quran later — all read through the same
`CorpusDatabaseProviding` infrastructure. A feature large enough to warrant its
own file (the Quran, most likely) can have one: `CorpusDatabase` is constructed
with a resource name and knows nothing about what is inside it.

---

## ⚠️ Nothing in here has been verified by a scholar

Two separate warnings, both blocking for V1. The adhkar are immediately below;
the 99 names are under [Sources](#sources). Neither the app nor this file may
present any of it as authoritative until someone has checked it.

## ⚠️ The adhkar text is NOT yet verified

**The adhkar in `corpus.sqlite` must not ship in V1 until someone has checked
them against a printed copy of Hisn al-Muslim.** It is third-party data that has
been reshaped by a script; no scholar and no maintainer of this project has read
it line by line.

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

## Sources

### Adhkar

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

### The 99 names

Vendored at `Tools/CorpusBuilder/data/divine_names.json` rather than downloaded
at build time, because the value in that file is the *cross-check*, not the
download — see below.

**⚠️ The English meanings are not verified, and the licence position is unsettled.
Both need resolving before V1.**

How the file was produced. Three public data sets were compared name by name,
with Arabic diacritics normalised away before comparison:

| source | licence | verdict |
| --- | --- | --- |
| [KabDeveloper/99-Names-Of-Allah](https://github.com/KabDeveloper/99-Names-Of-Allah) | none stated | used |
| [MuhammadAhsan-Shafiq/99-Names-of-Allah-JSON](https://github.com/MuhammadAhsan-Shafiq/99-Names-of-Allah-JSON) | none stated | agreed — used to confirm |
| [wnr-code/asmaul_husna](https://github.com/wnr-code/asmaul_husna) | MIT | **rejected** |

The first two agree **exactly** on all 99 Arabic names and all 99
transliterations. The MIT-licensed one — the only one that was actually
licensed for reuse — turned out to be wrong: it omits الأحد at position 67 and
shifts every name after it up by one, ending the list on اللّٰه instead of
الصَّبُور. Its own metadata says `"generator": "Gemini AI"`. That is the whole
argument for doing this comparison rather than taking the licensed file and
moving on, and it is why the file is vendored: the verification is the work, and
re-downloading would throw it away.

What that does and does not establish:

- **Arabic names and transliterations** — two independent sources agree
  character for character. High confidence, though still classical text that a
  reader of Arabic should check against a printed source.
- **English meanings** — taken from the first source alone. The two sources
  differ on 10 of the 99 (`The Sustainer` vs `The Nourisher`, `The Perceiver` vs
  `The Finder`, and so on), which is a fair reminder that rendering a divine name
  in English is interpretation rather than transcription. **Unverified.**
- **`explanation_en` is NULL for all 99, on purpose.** Every freely-licensed set
  of explanations found was AI-generated. An invented gloss on a name of God is
  exactly the failure this project must not ship, so the column waits for a
  source somebody has actually checked. The detail screen simply omits the
  section until then.
- **`reference`** holds Quran citations (`(1:3) (17:110)`) — chapter and verse
  numbers, which are facts rather than authorship.

On licensing: neither of the two agreeing sources states a licence, so neither
grants redistribution rights. What ships here is the canonical list itself —
classical religious text, standard transliterations, short conventional English
renderings and verse numbers — and none of the authored prose (`desc` fields) that
those repositories also carry. That is a defensible position rather than a settled
one. Before V1, either confirm it or replace this file with data from a source
that grants explicit permission.

### Tasbih presets

Written out in the build script rather than sourced from anywhere. They are five
short, universally-known phrases; there is no upstream worth taking a dependency
on, and no citation to print beside them.

**The target counts are conventional, not exclusive.** 33 / 33 / 34 is the tasbih
after an obligatory prayer, which is where those three come from and why they sum
to one hundred; the hundreds on *la ilaha illallah* and *astaghfirullah* are the
counts most commonly given for them as a daily practice. Other forms are reported
for all five. If the counter ever lets a user set their own target, that stops
being a caveat and becomes a setting — which is the better answer.

## Rebuilding `corpus.sqlite`

```bash
python3 Tools/CorpusBuilder/build_corpus_db.py
```

That downloads the two upstream adhkar JSON files and regenerates the database in
place, tasbih presets included.
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
| `tasbih_preset`  | `id` (matches `TasbihDhikr`'s identifier), the Arabic phrase, translation, target count, order |
| `divine_name`    | `id` 1–99 (the canonical order), the Arabic name, transliteration, English meaning, an empty explanation column, and Quran citations |

`PRAGMA user_version` is the schema version, and is `3` (`1` was adhkar only,
`2` added the tasbih presets). Bump it in the build script when the shape
changes, so a reader can tell two builds apart.

**A `tasbih_preset.id` is load-bearing.** The SwiftData progress store keys a
user's saved count on it, so renaming one orphans whatever they had counted. Treat
these ids as permanent.

### The citation is prose, not a structured reference

`reference_ar` / `reference_en` hold the citation exactly as upstream wrote it —
`Abu Dawood, No. 5074, and Ibn Majah, No. 3871. See: Sahih Ibn Majah, 2/332.` —
rather than a parsed book-and-number pair. Most citations name several books,
several numbers, and a grading, so splitting them into one book and one number
would throw information away and invent precision the source does not have. The
reading view prints the line as written.
