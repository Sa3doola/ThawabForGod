# Corpus

Read-only reference data that ships inside the app, as SQLite. Nothing in here is
ever written to at runtime — the databases are opened read-only, and anything the
*user* changes (bookmarks, counts, progress) belongs in `Core/Persistence`'s
SwiftData store instead.

Two files, both read through the same `CorpusDatabaseProviding` infrastructure —
`CorpusDatabase` is constructed with a resource name and knows nothing about what
is inside it, which is what makes a second one free:

- **`corpus.sqlite`** holds one table set per feature — the adhkar, the tasbih
  presets and the 99 names.
- **`quran.sqlite`** holds the Quran. Its own file rather than more tables in the
  first, for the reason this section anticipated: the text is an order of
  magnitude larger than everything in `corpus.sqlite` put together, and it has a
  different upstream, a different licence and its own rebuild step.
- **`tafsir.sqlite`** holds the commentaries, for the third time the same
  argument holds: another upstream, another licence — public domain by age
  rather than by anyone's permission — and a size that grows with every edition
  added rather than staying put.

---

## ⚠️ Nothing in here has been verified by a scholar

Two separate warnings, both blocking for V1. The adhkar are immediately below;
the 99 names are under [Sources](#sources). Neither the app nor this file may
present any of it as authoritative until someone has checked it.

**The Quran text is the exception, and deliberately so.** It is not data this
project assembled and hopes is right: it is Tanzil's published Uthmani text, used
verbatim, which they produce and monitor with specialists for exactly this
purpose. That is why it is the one source in Settings → Sources with no warning
beside it. What still holds is the rule that it must not be *edited* — see
[The Quran](#the-quran) below.

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

### A best-effort spot-check (2026-08-18)

Not the scholar pass above — this project has none of its own — but a sanity
check worth recording rather than leaving unsaid. A sample of the 34 rows
(the two ayat al-Kursi/last-two-ayat-of-al-Baqarah entries, the three
Quls, and half a dozen of the hadith-based morning duas, chosen for being
either the highest-stakes text or the easiest to get subtly wrong) was
diffed character-by-character against
[hisnmuslim.com](https://hisnmuslim.com/i/ar/1), the Arabic-original
companion site for the same book this data set draws from. Every sampled row
matched, with one cosmetic difference throughout: this corpus renders the
peace-be-upon-him salutation as the single ﷺ ligature (`U+FDFA`) wherever
hisnmuslim.com spells it out as `صلى الله عليه وسلم` — a font/encoding choice
common to most digital Islamic apps, not a textual variant, and not something
this note treats as a discrepancy.

This is a spot-check of roughly a quarter of the rows, by an AI agent with no
standing to certify religious text, not the line-by-line pass the warning
above asks for — it narrows the risk on the sample it covers without
discharging the warning for the rest. The two-line hadith citations were not
independently checked against the named books at all; that still needs a
reader with access to them.

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

#### A best-effort spot-check (2026-08-18)

Reading every row in `data/divine_names.json` turned up three plain English
spelling mistakes, unrelated to the translation-choice question above — copy
errors, not interpretation:

| # | field | was | now |
| - | --- | --- | --- |
| 33 | `meaning_en` | `The Maginificent` | `The Magnificent` |
| 89 | `transliteration` | `Al Mughi` | `Al Mughni` |
| 97 | `meaning_en` | `The Inhertior` | `The Inheritor` |

Fixed in the vendored JSON — never in `corpus.sqlite` itself, per the rule
below — and `corpus.sqlite` regenerated from it with
`build_corpus_db.py`, so the fix is reviewable as a data diff rather than a
binary one.

Two more things surfaced that are judgement calls rather than typos, left for
whoever does the real pass rather than decided here:

- **#91's transliteration, `Ad Daaarr`,** is the one entry whose doubled
  letters don't obviously map to its diacritics the way the rest of the list's
  do (compare `Al Ghaffaar`, `Al Qahhaar`). It may be correct — shadda on both
  the ض and the ر would produce something in this shape — but it reads as a
  typo next to its neighbours and deserves a second look from a reader who can
  parse the diacritics with more confidence than this pass did.
- **#17 (Ar-Razzaq) and #39 (Al-Muqeet) both render as "The Sustainer."** Two
  different names sharing an English gloss is not necessarily wrong — the
  roots are both about provision — but it means the app currently shows the
  same word twice for two names a reader would expect to read differently.
  Worth a more distinct rendering of one of them (Al-Muqeet is often given as
  "The Nourisher" or "The Maintainer" elsewhere) if this list gets a real
  editing pass.

### The Quran

**Source:** the [Tanzil Project](https://tanzil.net) — *two* of their texts,
both version 1.1, plus `quran-data.xml` for the chapter metadata and the
divisions.

| Text | What it is for |
| --- | --- |
| **Uthmani** | Every verse the reader ever sees. Stored verbatim in `verse.text`. |
| **Simple Clean** | Never displayed. Folded into `verse.text_normalized`, which is the only thing search matches against. |

**Why a second text rather than a folding of the first.** Uthmani orthography
writes a large class of words without the alef that modern spelling has, marking
it with a superscript instead: the mushaf spells ٱلسَّمَٰوَٰتِ, ٱلصَّٰلِحَٰتِ, ٱلْكَٰفِرِينَ.
Strip the diacritics and those become `السموت`, `الصلحت`, `الكفرين` — which is
what the index used to hold, and what nobody will ever type. The corpus shipped
that way at first, and the failure was silent: the screen said "no results" for
words that occur in the Quran hundreds of times. Tanzil's Simple Clean text is
the same verses in modern imla'i spelling, so folding *it* produces the tokens a
reader actually types. `QuranRepositoryTests` pins the six worst of those words
so the regression cannot come back quietly.

The second text is pinned by its own SHA-256 and carries its own copyright
block, which is stored beside the first in the `source` table — two rows,
`tanzil-uthmani` and `tanzil-simple-clean`, because the terms below ask for the
notice per text.

**Licence: Creative Commons Attribution 3.0**, with terms that shape how this is
built. Their copyright block states them in full and is reproduced *inside*
`quran.sqlite` — in the `source` table — because those terms ask for it to appear
in "all files derived from or containing substantial portion of this text". A
copy of the database on its own is therefore still compliant. The build fails
outright if the download arrives without that block.

The three obligations, and how each is met:

| Term | How |
| --- | --- |
| Verbatim copies only; **changing it is not allowed** | The text is inserted exactly as downloaded, and a SHA-256 of the verses is pinned in the build script — an upstream revision is a loud failure to be re-pinned deliberately, not a silent change to the mushaf the app ships |
| Source clearly indicated, with a link to tanzil.net | Settings → Sources carries the row, linking to tanzil.net |
| Notice reproduced in derived files | The `source` table, as above |

**One transformation is applied, and it is worth being explicit about.** For the
112 chapters that open with it, Tanzil delivers the basmala as a *prefix of verse
1*; the mushaf prints it above the chapter, unnumbered. The build moves it into
`surah.bismillah` so the reading screen can draw it as a heading. Not a word is
added, removed or altered — the same characters in the same order, stored in two
columns instead of one, and the reader sees them in the order the mushaf has
them. (The Tazkiya Tech Quran SDK, working from the same upstream, makes the same
cut for the same reason.) Al-Fatiha is left alone, its basmala being verse 1, and
At-Tawba has none. `QuranRepositoryTests` pins all of that.

**A second transformation, on the search text only.** The basmala is cut off
verse 1 of the same 112 chapters there too. Without it, searching "بسم الله
الرحمن الرحيم" would return every chapter's first verse and then draw each of
them with text that does not contain those words. It is a verse exactly twice —
1:1, and 27:30, where Sulayman's letter opens with it — and the test says so.

**What is not verified:** nothing about the *text* is in doubt. The divisions —
juz, hizb, rub el hizb, page numbers, sajda markers — come from Tanzil's metadata
rather than from a printed mushaf, and while the canonical boundaries are pinned
in tests, a full page-by-page check against a printed Madina mushaf has not been
done. The page numbers in particular are unused today; a paged reading mode would
be the point at which they need one.

### The tafsir

**Source:** Tafsir al-Jalalayn, begun by Jalal al-Din al-Mahalli (d. 864 AH /
1459 CE) and completed by his pupil Jalal al-Din al-Suyuti (d. 911 AH / 1505 CE).

**Licence: public domain by age.** That is the whole reason it is this tafsir and
not a better-known modern one, and the reasoning is worth keeping because the
next person will ask.

**Every distributor in this space publishes the same thing about licensing:
nothing.** Checked in August 2026:

| Source | What it says |
| --- | --- |
| Tanzil (translations) | "for non-commercial purposes only… you need to obtain necessary permission from the translator or the publisher" |
| Itani / ClearQuran | CC BY-**NC-ND** — non-commercial, and no derivatives |
| quranenc.com | links to "Terms and Policies"; no terms on the page |
| qul.tarteel.ai | JSON and SQLite downloads, no licence field anywhere |
| Quran Foundation API | content permitted only "as integral to the end-user experience of the Application"; anything else needs a separate written agreement |
| alquran.cloud | translations are "from their rights-holders or sourced from public-domain editions" — without saying which is which |

So the only texts whose status can be established *independently of whoever is
hosting them* are the ones old enough to be public domain everywhere, and that
is the standard this file already holds the rest of the corpus to. Al-Jalalayn is
also the tafsir actually built for a per-verse screen: a terse gloss meant to be
read *beside* the verse, quoting the words it explains between ﴿ ﴾ ornaments.

**Arabic only, deliberately.** The classical Arabic is free; every English
translation of it belongs to its modern translator — Feras Hamza's is © 2007 the
Royal Aal al-Bayt Institute, Aisha Bewley's is her own. Nothing English gets
bundled until that is settled, which is the same rule this file records for the
Quran's translations. An English-reading user therefore gets nothing from this
slice yet, and that is a known gap rather than a bug.

**The text is taken from a mirror**, `spa5k/tafsir_api`, which copies what
quran.com and altafsir.com carry. That indirection is acceptable *here and only
here*: the underlying work is five centuries old, so there is no licence to
inherit from the host — only a transcription to check. It is pinned by SHA-256 in
the build script so the transcription cannot change under the app silently.

**226 verses have no note, and that is the commentary rather than a gap.** The
two Jalals pass over the plain formulas — "those who believe and do righteous
deeds", and the like — that need no gloss. This was checked rather than assumed:
the independently-sourced *English* edition of the same tafsir carries, for
exactly those verses, the verse restated with nothing added. Those verses get no
row, and the app says the commentary has no note here — it does not show a blank,
and it does not borrow the note from the verse above, which would print a gloss
of one verse under another. `TafsirRepositoryTests` pins the count.

**What is not verified:** nobody on this project has read the commentary against
a printed edition. It is not in the same position as the adhkar — this is a
famous text with a fixed wording, transcribed by several independent projects
that agree — but the transcription has had no line-by-line check here, and this
note should not be deleted until it has.

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

## Rebuilding `tafsir.sqlite`

```bash
python3 Tools/CorpusBuilder/build_tafsir_db.py
```

Build `quran.sqlite` first — the tafsir is checked against the verses it comments
on, and the script refuses to run without it.

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

## Rebuilding `quran.sqlite`

```bash
python3 Tools/CorpusBuilder/build_quran_db.py
```

That downloads the Uthmani text and `quran-data.xml` from Tanzil and regenerates
the database in place. Pass `--text` and `--metadata` to build from local copies
instead — which is also how to rebuild without hitting the network twice.

The same rule as above: **the script is the only thing that writes this file, and
rows must not be edited by hand.** Here it is not only reproducibility — an edit
is a change to the Quran text, which the licence forbids and which no reviewer
could see in a binary diff.

### Schema

| table | holds |
| --- | --- |
| `surah` | the 114 chapters: three name spellings, verse count, where and when revealed, and the basmala heading (`NULL` for Al-Fatiha and At-Tawba) |
| `verse` | all 6,236 verses: the Uthmani text, a search-normalized copy, the juz / hizb / rub el hizb it falls in, its mushaf page, and its sajda kind where it has one |
| `juz`, `hizb`, `rub_el_hizb` | the divisions, as ranges to jump to |
| `source` | Tanzil's copyright notice, verbatim — see above |
| `verse_fts`, `surah_fts` | FTS5 indexes over the normalized text and the three name spellings |

`PRAGMA user_version` is the schema version, and is `2` (`1` was `surah` and
`verse` alone, Arabic only).

**`text_normalized` is built here, not on device.** It is the verse with every
diacritic dropped and the ambiguous letters folded together — alef forms to `ا`,
ta marbuta to `ه`, alef maqsura to `ي` — so that a reader typing plain Arabic
matches a fully vowelled text. Normalizing 6,236 verses to answer one query would
be the whole corpus walked per keystroke.

**A known limit, for whoever builds search.** Folding drops the superscript alef,
so `ٱلْعَٰلَمِينَ` normalizes to `العلمين` — the Uthmani spelling without its
diacritics, not the modern `العالمين` that a reader is more likely to type. The
same applies to `الرحمن`. Tanzil publish a separate "simple" (imlaei) edition
that spells those alefs out, and pulling it in as a second column is the obvious
answer when full-text search lands. It is not a problem today: nothing queries
these indexes yet.

### The citation is prose, not a structured reference

`reference_ar` / `reference_en` hold the citation exactly as upstream wrote it —
`Abu Dawood, No. 5074, and Ibn Majah, No. 3871. See: Sahih Ibn Majah, 2/332.` —
rather than a parsed book-and-number pair. Most citations name several books,
several numbers, and a grading, so splitting them into one book and one number
would throw information away and invent precision the source does not have. The
reading view prints the line as written.
