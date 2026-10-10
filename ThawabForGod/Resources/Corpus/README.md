# Corpus

Read-only reference data that ships inside the app, as SQLite. Nothing in here is
ever written to at runtime — the databases are opened read-only, and anything the
*user* changes (bookmarks, counts, progress) belongs in `Core/Persistence`'s
SwiftData store instead.

Four kinds of file, all read through the same `CorpusDatabaseProviding` infrastructure —
`CorpusDatabase` is constructed with a resource name and knows nothing about what
is inside it, which is what makes each one after the first free:

- **`corpus.sqlite`** holds one table set per feature — the adhkar, the tasbih
  presets and the 99 names.
- **`quran.sqlite`** holds the Quran: the public (`tanzil`) build, in Mushaf's
  schema. Its own file rather than more tables in the first: the text is an order
  of magnitude larger than everything in `corpus.sqlite` put together, and it has
  a different upstream, a different licence and its own rebuild step. Where the
  full (`qul`) build has been made locally, **`quran-mushaf.sqlite`** sits beside
  it — git-ignored — and the app prefers it.
- **`Packs/`** holds the commentaries and translations, one file per edition, for
  the same argument again: another upstream and another licence per edition. The
  repository carries one, `tafsir-ar-jalalayn.sqlite`, public domain by age; the
  QUL packs are built locally and git-ignored. They replaced `tafsir.sqlite` at M3
  of the Quran migration (`QURAN_MIGRATION_PLAN.md`), which is also when
  `Tools/QuranBuilder` took over from the two Python scripts that built the old
  files; see [The Quran](#the-quran) and
  [Building the Quran data](#building-the-quran-data).
- **`hadith.sqlite`** holds the two Sahihs, and settles the argument: at
  twenty-four megabytes it is larger than the other three together, and only a
  reader who opens that tab ever pays to page any of it in.

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
- which chapter it is filed under

And per chapter:

- the Arabic title
- **the English title, which this project wrote** — see below

Until that has happened, the app must not present this content as verified, and
this note must not be deleted. The reading list carries the attribution and this
warning on screen, so a reader is told rather than left to assume.

### A best-effort spot-check (2026-08-18)

Recorded for what it covers, which is now a small fraction of the corpus. It was
made against the **previous** 34-row data set, before the whole book replaced it
— so it applies only to the morning-and-evening material and only where that
material survived the swap.

A sample of the 34 rows (the two ayat al-Kursi/last-two-ayat-of-al-Baqarah
entries, the three Quls, and half a dozen of the hadith-based morning duas,
chosen for being either the highest-stakes text or the easiest to get subtly
wrong) was diffed character-by-character against
[hisnmuslim.com](https://hisnmuslim.com/i/ar/1), the Arabic-original companion
site for the same book. Every sampled row matched, with one cosmetic difference
throughout: that corpus rendered the peace-be-upon-him salutation as the single
ﷺ ligature (`U+FDFA`) wherever hisnmuslim.com spells it out as
`صلى الله عليه وسلم` — a font/encoding choice common to most digital Islamic
apps, not a textual variant.

This was a spot-check of roughly a quarter of *those* rows, by an AI agent with
no standing to certify religious text. It does not touch the 233 adhkar the
current corpus added.

## Sources

### Adhkar

**Hisn al-Muslim** (حصن المسلم) by Sa‘id bin Ali bin Wahf al-Qahtani, in the
widely-circulated JSON transcription of the book — 132 chapters, 267 adhkar,
Arabic only. Vendored at `Tools/CorpusBuilder/data/adhkar.json` and built by
`build_corpus_db.py`.

It replaced [Seen-Arabic/Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB)
(MIT, © 2024 Seen Arabic), whose scope was exactly what its name said: 34 adhkar,
morning and evening, and nothing else. **That swap traded verifiability for
coverage, and the trade should be understood rather than discovered.** What was
lost, per dhikr:

| | before (34 rows) | now (267 rows) |
| --- | --- | --- |
| Arabic text | yes | yes |
| repeat count | yes | yes |
| English translation | yes | **no** |
| transliteration | yes | **no** |
| hadith citation | yes | **no** |
| reported virtue (fadl) | sometimes | **no** |

The citation is the one that matters. This file used to be able to say that a
reader could check any dhikr against the book and number printed under it; now
the attribution is the *book*, named once on the browse screen, and the chapter
is as fine-grained as the reference gets. Restoring per-dhikr citations is a data
problem — a transcription that carries them, licensed — not a code one.

The licence position is **unsettled**, the same way the 99 names' is. The
underlying text is the classical duas of the Quran and the hadith, arranged and
selected by a modern author (d. 2018); this transcription is published without a
licence statement, as most copies of it are. What ships is the Arabic text
itself, without any of the compiler's own apparatus — no introductions, no
footnotes, no gradings, no translations. That is a defensible position rather
than a settled one, and it needs confirming before V1.

**Arabic only, knowingly.** Every English translation of Hisn al-Muslim belongs
to its modern translator, so an English-reading user gets Arabic text under an
English chapter heading until that is resolved — the same wall the tafsir and
hadith slices hit, and for the same reason.

#### The chapter titles and grouping are this project's

`Tools/CorpusBuilder/data/adhkar_categories.json` is **not** upstream data. It
holds three things this project wrote, one row per chapter:

- **`slug`** — the stable identifier the app keys on. Deliberately not the
  chapter number, which is positional: a corrected order would silently make a
  saved shortcut or an activity record name a different chapter. The same
  argument `HadithID` makes.
- **`title_en`** — an English rendering of the Arabic chapter title.
  **Unverified.** These are labels, not scripture — "Supplication when entering
  the market" — and rendering one is a much lower-stakes act than translating a
  dua, which is why they are here and translations are not. They still need a
  reader who knows both languages to go through them.
- **`group`** — one of the twelve headings the browse screen cuts the list on.
  Hisn al-Muslim has no such grouping; it is one flat sequence, which works bound
  in the hand and does not work as 132 rows on a phone. The book's own order is
  kept in `category.sort_order` and is what orders the chapters *inside* a group,
  so nothing is lost — only added.

#### What the build changes about the source text

Three mechanical passes, each in `build_corpus_db.py` and each reversible by
reading the script beside the vendored file. Nothing is hand-edited into either.

1. **NFKC**, which folds the Arabic presentation forms the source carries in
   three chapter titles — `اﻟﻤﺠلس` is written with initial/medial glyph
   codepoints rather than letters, so it looks right on screen and matches
   nothing a reader types. The ornate parentheses `﴿ ﴾` that mark Quranic
   quotation have no NFKC mapping and survive intact.
2. **A corrections table** for transcription damage from the source's PDF
   origin: `نز` came out as `تر` under a legacy encoding, turning منزلا into the
   non-word مترلا. Two entries today, both in chapter titles.
3. **Whitespace**, collapsed to single spaces.

And one substantive rule, which the build prints every application of:

**Where a dhikr's own prose states a repeat count and the source's `count` field
disagrees, the prose ships.** The prose is the book's words; the count field is
somebody's metadata about them. It applies only when every count note in the
text agrees on one number *and* the note is the last parenthesis in it — two
conditions each earned by a case that breaks without them (`(عشرَ مرَّات) ، أَوْ
(مرَّةً واحدةً عند الكسل)` is a choice the book offers, not a number to read off;
the chapter on dreams puts `(three times)` on one step of a list of actions). It
fires on three of the 267, all of them a `(سبع مرات)` or `(ثلاث مرات)` the
`count` field recorded as 1:

| chapter | dhikr | text says | field said |
| --- | --- | --- | --- |
| `morning-evening` | 9 — حَسْبِيَ اللَّهُ… | 7 | 1 |
| `fear-of-ruler` | 2 — اللَّهُ أَكْبَرُ، اللَّهُ أَعَزُّ… | 3 | 1 |
| `visiting-the-sick` | 2 — أَسْأَلُ اللَّهَ الْعَظيمَ… | 7 | 1 |

These three are worth a second look by whoever does the scholar pass; the rest
of the counts were taken from the source as given.

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

There are now **two builds of the Quran, one schema**, and which one an app carries
is a licensing question before it is a technical one.

| Profile | What it is | Where its inputs come from | Committed? |
| --- | --- | --- | --- |
| **`tanzil`** — the public build | The text, the search text and the divisions. No printed page layout, so the app offers separated (verse-by-verse) reading only | The [Tanzil Project](https://tanzil.net), downloaded and pinned by the build | Yes: `quran.sqlite` here |
| **`qul`** — the full Mushaf | The same, plus the King Fahd Complex's Madani V2 page layout (1421H print: 604 pages, 15 lines), its word-by-word Hafs text, the per-page glyph codes and fonts, and the header, surah-name and juz-name fonts | The [Quranic Universal Library](https://qul.tarteel.ai) (Tarteel), behind a free account, kept in `QuranData/raw/` | **Never.** Built locally, git-ignored |

**Why the second is never committed.** QUL publishes no licence for any of it; its
FAQ says licensing is "per resource", and no resource page states one. This
repository is public and MIT-licensed, so nothing derived from QUL may enter it —
not the database, not the fonts, not the packs (QURAN_MIGRATION_PLAN.md, D1).
Every QUL file is listed in `QuranData/SOURCES.md` with its SHA-256, its original
publisher and its status, which is `unconfirmed` for all of them; the build
refuses an input whose hash differs. A full App Store build ships the QUL data
only once the requests in the Mushaf project's `docs/release/license-requests.md`
are answered in writing; until then a Release build without it fails on purpose,
and the public build is the Tanzil one.

#### The Tanzil build

**Source:** *two* Tanzil texts, both version 1.1, plus `quran-data.xml` for the
chapter metadata and the divisions.

| Text | What it is for |
| --- | --- |
| **Uthmani** | Every verse the reader ever sees. Stored verbatim in `ayah.text_hafs`. |
| **Simple Clean** | Never displayed. Stored in `ayah.text_imlaei` and folded into the search index, which is the only thing search matches against. |

**Why a second text rather than a folding of the first.** Uthmani orthography
writes a large class of words without the alef that modern spelling has, marking
it with a superscript instead: the mushaf spells ٱلسَّمَٰوَٰتِ, ٱلصَّٰلِحَٰتِ, ٱلْكَٰفِرِينَ.
Strip the diacritics and those become `السموت`, `الصلحت`, `الكفرين` — which is
what the index used to hold, and what nobody will ever type. The corpus shipped
that way at first, and the failure was silent: the screen said "no results" for
words that occur in the Quran hundreds of times. Tanzil's Simple Clean text is
the same verses in modern imla'i spelling, so folding *it* produces the tokens a
reader actually types. (The QUL build does the same with QUL's own imla'i text.)

**Licence: Creative Commons Attribution 3.0**, with terms that shape how this is
built. Their copyright block states them in full and is reproduced *inside* the
database — one `meta` row per text, `source:tanzil-uthmani:notice` and
`source:tanzil-simple-clean:notice`, beside each text's name, link and licence —
because those terms ask for it to appear in "all files derived from or containing
substantial portion of this text". A copy of the database on its own is therefore
still compliant. The build fails outright if a download arrives without that block.

| Term | How |
| --- | --- |
| Verbatim copies only; **changing it is not allowed** | The text is inserted exactly as downloaded. A SHA-256 of each text's verses is pinned in `Tools/QuranBuilder/profiles/tanzil.json` — over the verses, not the file, whose copyright block carries the current year — so an upstream revision is a loud failure to be re-pinned deliberately, never a silent change to the Quran the app ships |
| Source clearly indicated, with a link to tanzil.net | Settings → Sources carries the row, linking to tanzil.net |
| Notice reproduced in derived files | The `meta` rows, as above |

**One transformation is applied, and it is worth being explicit about.** For the
112 chapters that open with it, Tanzil delivers the basmala as a *prefix of verse
1*; the mushaf prints it above the chapter, unnumbered. The build lifts it off, so
verse 1 of Al-Baqara is الٓمٓ, and records that the chapter opens with it
(`surah.bismillah_pre`). Not a word of any verse is added, removed or altered.
Al-Fatiha is left alone, its basmala being verse 1, and At-Tawba has none. The
same cut is made on the search text, or searching "بسم الله الرحمن الرحيم" would
return every chapter's first verse and then draw each with text that does not
contain those words.

**The test of all of that is the database the app shipped before the migration.**
Until M3, `TanzilProfileTests` held the new build to the old `quran.sqlite` row
for row: every verse's text byte-identical, every verse's juz, hizb and rub el
hizb identical, the same fifteen sajdas, every verse's search fold identical, and
the same verses found for the same words. M3 replaced that file, so it holds the
build to fingerprints of each of those taken from it just before
(`PreMigrationCorpus` in the builder's tests).

**What is not verified:** nothing about the *text* is in doubt. The divisions —
juz, hizb, rub el hizb, manzil, ruku, sajdas — come from Tanzil's metadata rather
than from a printed mushaf. The juz boundaries are checked against a static table,
and Tanzil and QUL agree on every juz, hizb, manzil and sajda — but not on one rub
el hizb (quarter 106 begins at 15:49 in QUL, at 15:50 in Tanzil) and not on the
rukus (556 against 558). Each build keeps its own source's, and a check against a
printed Madina mushaf has not been done. Tanzil's page
table is deliberately **not** used: 56 verses start one page away from the V2
print, so a fallback page number would not be the printed page, and the fallback
build has no Page view at all.

#### The QUL build

Everything above, and the page itself: the V2 layout puts every word on its line
of its page, and `word.glyph_v2` names the glyph that draws it in that page's own
font. The fonts, the layout and the word-by-word text come from the King Fahd
Glorious Quran Printing Complex (KFGQPC) by way of QUL. `KFGQPC-HafsUthmanic.ttf`,
which this folder's sibling `Fonts/Quran/` already ships, is byte-identical to
QUL's copy and carries the Complex's own grant ("free to use, copy and
distribute; must not be sold or modified"); nothing else from QUL has a grant.

### The tafsir

Commentaries now ship as **packs**: one SQLite file per edition, named by kind —
`tafsir-<id>`, and beside them `translation-<id>` and `surah-info-<id>` — each
describing itself, in English and Arabic, in its own `pack` table. The app finds
them by name; there is no manifest to keep in step (QURAN_MIGRATION_PLAN.md, T15).

| Pack | Licence | Build | Committed? |
| --- | --- | --- | --- |
| `tafsir-ar-jalalayn` — Tafsir al-Jalalayn | **Public domain by age** | `tanzil` | Yes, from M3 |
| `tafsir-ar-muyassar` — Tafsir al-Muyassar (KFGQPC) | unconfirmed | `qul` | Never |
| `tafsir-en-mukhtasar` — the Abridged Explanation (Tafsir Center for Quranic Studies) | unconfirmed | `qul` | Never |
| `translation-en-sahih-international` — Saheeh International | unconfirmed | `qul` | Never |
| `surah-info-en` — surah introductions (QUL) | unconfirmed (author not recorded) | `qul` | Never |

#### Tafsir al-Jalalayn

**Source:** Tafsir al-Jalalayn, begun by Jalal al-Din al-Mahalli (d. 864 AH /
1459 CE) and completed by his pupil Jalal al-Din al-Suyuti (d. 911 AH / 1505 CE).

**Licence: public domain by age.** That is the whole reason it is the one
commentary this repository carries, and the reasoning is worth keeping because the
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
is the standard this file holds the rest of the corpus to. That is also why the
QUL packs above are built and tested here but never committed: they are what the
full build would ship once permission is in writing, not what this repository may
publish. Al-Jalalayn is also the tafsir actually built for a per-verse screen: a
terse gloss meant to be read *beside* the verse, quoting the words it explains
between ﴿ ﴾ ornaments.

**Arabic only, in the public build.** The classical Arabic is free; every English
translation of it belongs to its modern translator — Feras Hamza's is © 2007 the
Royal Aal al-Bayt Institute, Aisha Bewley's is her own. A public build therefore
offers an English reader no commentary; the QUL build's English pack is the
licensing question above, not a technical one.

**The text is taken from a mirror**, `spa5k/tafsir_api`, which copies what
quran.com and altafsir.com carry. That indirection is acceptable *here and only
here*: the underlying work is five centuries old, so there is no licence to
inherit from the host — only a transcription to check. It is pinned by the
SHA-256 of its notes in `Tools/QuranBuilder/profiles/tanzil.json`, so the
transcription cannot change under the app silently.

**The note is not edited either.** The pack stores HTML, so each note goes through
one fixed conversion — escaped, its line breaks marked, wrapped in a paragraph —
and `JalalaynPackTests` inverts it and requires the pre-migration text back, byte for byte,
for all 6,010 notes.

**226 verses have no note, and that is the commentary rather than a gap.** The
two Jalals pass over the plain formulas — "those who believe and do righteous
deeds", and the like — that need no gloss. This was checked rather than assumed:
the independently-sourced *English* edition of the same tafsir carries, for
exactly those verses, the verse restated with nothing added. Those verses get **no
row** in the pack, not a pointer to a neighbour as a QUL tafsir's grouped verses
have, and the app says the commentary has no note here — it does not show a blank,
and it does not borrow the note from the verse above, which would print a gloss of
one verse under another (QURAN_MIGRATION_PLAN.md, T16). The count is pinned in the
build, and every note — so every verse that has one — is checked against a
fingerprint of the `tafsir.sqlite` the app shipped before the migration.

**What is not verified:** nobody on this project has read the commentary against
a printed edition. It is not in the same position as the adhkar — this is a
famous text with a fixed wording, transcribed by several independent projects
that agree — but the transcription has had no line-by-line check here, and this
note should not be deleted until it has.

### The hadith

**Source:** the Arabic editions of
[fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api), with
[AhmedBaset/hadith-json](https://github.com/AhmedBaset/hadith-json) as the
cross-check and the source of the Arabic kitab titles.

**Two collections only — Sahih al-Bukhari and Sahih Muslim — and no gradings.**
That is the whole shape of this slice, and it follows from one fact: **a hadith's
grading is what tells a reader whether to act on it.** Sunan Abi Dawud, Jami'
at-Tirmidhi, Sunan an-Nasa'i and Sunan Ibn Majah were compiled to *include* weak
narrations, not to exclude them, so shipping one of those without a grading would
put a text in front of a reader with the app's implicit assurance behind it and
nothing to say how sound it is.

The gradings would therefore have to ship too, and they cannot. Every grader in
the freely-published data is modern — al-Albani (d. 1999), Shu'ayb al-Arna'ut
(d. 2016), Zubair Ali Zai (d. 2013), Muhammad Muhyi al-Din Abd al-Hamid
(d. 1972) — and their judgements are 20th-century scholarship, in copyright
everywhere, which no mirror republishing them has the right to license on.

The two Sahihs are the exception, and structurally so: their compilers graded the
contents by deciding what went in. "Sahih" is the title of the book rather than a
modern annotation on top of it, which is a fact about *which collection a
narration is in* and needs nobody's permission to state.

**Arabic only, deliberately** — the same wall the tafsir hit. The Arabic of both
Sahihs has been in the public domain for eleven centuries; every English
translation of them is modern and owned, whatever a mirror's own repository
licence says about the code beside the data. An English-reading user gets the
collection and kitab names and nothing else. That is a known gap, not a bug.

#### Why two sources

The text and the **reference numbers** come from fawazahmed0, which is released
under the Unlicense. That dedication covers what its author can give away and
nothing more — which is exactly why the underlying work has to be public domain
by age for any of this to be shippable, the same reasoning the tafsir section
sets out above.

It was chosen over the more widely-mirrored AhmedBaset data set for one reason:
**it carries the numbers a reader can cite.** Its last hadith of Bukhari is 7563,
the standard total; AhmedBaset numbers the same narration 7277, because it
indexes sequentially and merges what sunnah.com splits. A citation is the whole
point of printing a reference number, so the edition that gets them right is the
one the corpus is built from.

AhmedBaset is still downloaded on every build, and does two jobs:

| What | Result |
| --- | --- |
| **Cross-check on the text** | 7,266 of its 7,277 Bukhari narrations and 7,278 of its 7,459 from Muslim fold word-for-word onto this corpus. **Not one is a textual disagreement** — the shortfall is narrations fawazahmed0 files under a neighbouring number. Pinned as a floor; a drop fails the build. |
| **The Arabic kitab titles** | fawazahmed0 publishes the divisions in English only. The two agree on all 97 of Bukhari's titles and all 57 of Muslim's, *exactly*, which is what makes joining the Arabic ones on the division number safe rather than hopeful. The build asserts it. |

It also supplies **which kitab each narration belongs to**, because fawazahmed0
publishes that wrongly. Each entry's own `reference` is `{book: 0, hadith: 0}` on
hundreds of real narrations, and the per-section reference ranges are visibly
broken for Sahih Muslim — kitab 15 is said to end at 3397 and kitab 16 to start
at 388, which cannot both be true of a book read front to back. Placing
narrations by those ranges would have hung the wrong kitab name over a fifth of
Sahih Muslim. So the divisions are taken from the cross-check by matching folded
text, and the 44 narrations that match nothing inherit the kitab of the one
before them — which is sound only because both sources list the collection in the
same order, and the build's non-decreasing check is what actually tests that.

#### Three things about the numbering

**Empty entries are continuation numbers, not missing text.** sunnah.com gives one
narration several reference numbers where the printed editions group them —
Bukhari 5709 carries 5709 through 5712 — and represents that as the text on the
first number and empty entries on the rest. Nine of Bukhari's entries and 203 of
Muslim's are empty for this reason. They are neither dropped nor shown blank:
each extends the preceding narration's `number_last`, so the row says it covers
5709–5712 and a reader who came looking for 5711 finds it where it actually is.
Two entries — the opening paragraphs of Muslim's introduction, which sunnah.com
numbers but carries no Arabic for — have nothing before them to extend and are
dropped; the count is pinned so a change has to be looked at.

**Twenty-six reference numbers carry two narrations.** Sahih al-Bukhari prints two
hadith under one number in those places, and both are cited as that number. The
`part` column orders them and does nothing else — no screen shows it.

**Sahih al-Bukhari 4757 contains one Latin letter**, a stray `v` where the
upstream transcription lost an opening `﴿` before a quoted verse. One character in
14,940 narrations. It is left exactly as it arrived, because this project does not
edit the text it ships, and pinned in the build so that a *second* one is loud —
because a Latin letter appearing in a narration would otherwise mean a translated
column had been read by mistake, which is the one packaging error here that would
ship somebody's copyrighted work.

#### One text, not two

The Quran's build downloads a second copy of the text because Uthmani orthography
spells ٱلسَّمَٰوَٰتِ, whose letters alone are `السموت`. That does not apply here: the
Sahihs are printed in ordinary vowelled Arabic, so stripping the marks from
ٱلْأَنْصَارِيُّ leaves `الأنصاري`, which is what a reader types. The search index is
folded from the displayed text itself, and the folded form is not *stored* — it
goes into a contentless FTS5 index and nowhere else, which is nine megabytes this
file does not carry.

**What is not verified:** nobody on this project has read either collection
against a printed edition. Two mirrors agreeing is evidence that neither
transcription drifted, not that the transcription was right to begin with.

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

## Rebuilding `hadith.sqlite`

```bash
python3 Tools/CorpusBuilder/build_hadith_db.py
```

Downloads both upstreams — roughly forty megabytes of JSON — and writes the
database in place. `--source path/to/json/` builds from a local directory instead,
holding `ara-bukhari.json`, `ara-muslim.json`, `bukhari.json` and `muslim.json`.

The build refuses to finish if any of its pinned counts has moved: the last
reference number of each collection, the number of kitab, how many entries are
continuations, how many narrations inherit their kitab, how many carry a Latin
letter, and how much of the cross-check still folds onto the corpus. Every one of
those is a fact about the published collections rather than about a mirror, so a
mismatch means somebody should read the diff before the app ships it.

## Rebuilding `corpus.sqlite`

```bash
python3 Tools/CorpusBuilder/build_corpus_db.py
```

Regenerates the database in place from the three vendored files in
`Tools/CorpusBuilder/data/` — `adhkar.json`, `adhkar_categories.json` and
`divine_names.json` — plus the tasbih presets written out in the script. It
downloads nothing: everything it reads is checked in, which is what makes a
correction a reviewable diff rather than a request to trust a re-fetch.

It prints what it wrote, and it prints every repeat count it took from a dhikr's
prose rather than from the source's `count` field. Three today; a fourth
appearing is a signal to go and look, not a failure.

The script is the only thing that writes this file. **Do not edit rows by hand**:
a hand-edited database cannot be reproduced, and the next rebuild silently throws
the edit away. Corrections belong in a vendored JSON, or — where they are
mechanical, like the NFKC fold — in the script.

### Schema

| table            | holds                                                                |
| ---------------- | -------------------------------------------------------------------- |
| `category_group` | the twelve headings the browse screen cuts on (matches `AdhkarGroup`'s raw values), and their order |
| `category`       | one row per chapter: `id` (the stable slug), both titles, its group, and its chapter number in the book |
| `dhikr`          | the Arabic text, which chapter it is in, its place in that chapter, and its repeat count |
| `tasbih_preset`  | `id` (matches `TasbihDhikr`'s identifier), the Arabic phrase, translation, target count, order |
| `divine_name`    | `id` 1–99 (the canonical order), the Arabic name, transliteration, English meaning, an empty explanation column, and Quran citations |

`PRAGMA user_version` is the schema version, and is `4` (`1` was adhkar only,
`2` added the tasbih presets, `3` the divine names, `4` replaced the two-category
adhkar tables with the whole book). Bump it in the build script when the shape
changes, so a reader can tell two builds apart.

**A `category.id` is load-bearing**, and so is `dhikr.id`. Home's shortcut circle
and the `noor://adhkar?period=…` deep link both name `morning-evening` in Swift,
and a recent-activity record stores whichever slug the reader was last in. The
`dhikr.id` is derived from the source's own chapter and item numbers rather than
from insertion order, so a rebuild cannot renumber one. Treat both as permanent.

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

## Building the Quran data

```bash
swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile tanzil
swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul    # needs QuranData/raw
swift test --package-path Tools/QuranBuilder
```

`Tools/QuranBuilder` (its README has the detail) is the one writer of the Quran,
its packs and the curated ayah list. The `tanzil` profile downloads Tanzil's two
texts, `quran-data.xml` and the Jalalayn mirror once, into `QuranData/raw/tanzil/`
and `QuranData/raw/jalalayn/`, and reads them from there afterwards; the `qul`
profile reads the QUL downloads in `QuranData/raw/` and verifies each against
`QuranData/SOURCES.md`. Both write to `QuranData/out/<profile>/`, git-ignored,
and once every check has passed **install** what they built here — the database
and its packs into this folder (`Packs/` flattens into the bundle root, so the app
finds packs by file prefix), and for `qul` the three QUL faces into
`Resources/Fonts/Quran/`. The `qul` profile also fills `QuranData/Fonts/madaniV2/`
with the 604 page fonts, a folder the app target references.

**What is committed and what is local:**

| | Committed | Local only |
| --- | --- | --- |
| Inputs | `QuranData/SOURCES.md`, `QuranData/fonts-v2.sha256` (hashes and notes, no content); the Tanzil and Jalalayn pins in `profiles/tanzil.json` | `QuranData/raw/` — the QUL downloads, and the cached Tanzil and Jalalayn ones |
| Outputs | The `tanzil` build — `quran.sqlite` and `Packs/tafsir-ar-jalalayn.sqlite` here; the page-font folder's README | `quran-mushaf.sqlite` and the four QUL packs here, the QUL header, surah-name and juz-name fonts in `Resources/Fonts/Quran/`, the 604 page fonts; everything in `QuranData/out/` |

The same rule as everywhere in this folder: **the builder is the only thing that
writes these files, and rows must not be edited by hand.** For the Quran it is not
only reproducibility — an edit is a change to the Quran text, which Tanzil's
licence forbids and which no reviewer could see in a binary diff. Nothing in the
pipeline changes a word of the Quran or of a commentary: the text goes in as it
was downloaded, the one cut (the basmala off verse 1) moves words rather than
altering them, and the tests compare the result with what the app shipped before
the migration.

**A Release build of the app refuses to proceed without the full data** — the
installed `qul` database, its four packs, the three QUL faces and all 604 page
fonts — naming what is missing and the command above. A Debug build only warns, so a public clone builds and runs on
the Tanzil build (QURAN_MIGRATION_PLAN.md, T4).

### Schema

Mushaf's schema 3, the same for both builds; what a build lacks it leaves empty,
and `meta.capabilities` says what it filled.

| table | holds | `tanzil` | `qul` |
| --- | --- | --- | --- |
| `surah` | the 114 chapters: Arabic (the printed headers' spelling), English and transliterated names, ayah count, where and in what order revealed, and whether it opens with the basmala | ✓ | ✓ |
| `ayah` | all 6,236 ayahs: the displayed text (`text_hafs`), the search text (`text_imlaei`), juz, hizb, rub el hizb, manzil, ruku, and the sajda kind where there is one | ✓ | ✓ |
| `ayah_fts` | FTS5, contentless: the folded search text and its particle stems | ✓ | ✓ |
| `word` | the word-by-word Hafs text with each ayah's end marker, and its V2 glyph code | | ✓ |
| `mushaf_line`, `mushaf_page`, `marker` | the printed page: every line of the 604 pages, each page's ayahs and divisions, the margin marks | | ✓ |
| `font_ligature` | which string draws each surah header, surah name and juz name in the QUL fonts | | ✓ |
| `meta` | schema version, profile, capabilities, the input hashes, and for Tanzil each text's notice, name, link and licence | ✓ | ✓ |

A pack holds `pack` (one row: kind, language, names and authors in English and
Arabic, direction, source and licence), `meta`, a contentless `pack_fts`, and its
kind's table — `tafsir` (ayah, its group's owner, the owner's HTML), `translation`
(ayah, text, footnotes) or `surah_info`.

**The search text is folded at build time, by the same code that folds every
query.** `Packages/ArabicText`'s `ArabicNormalizer` drops every combining mark, the
tatweel and the small waw and yeh of Uthmani spelling, folds the alef forms to
`ا`, ta marbuta to `ه`, alef maqsura to `ي` and the hamza seats to their letters,
and splits on everything that is not a letter or a digit. The app's
`ArabicSearchQuery` calls it; the hadith index, still built by
`build_hadith_db.py`, is held to it by a parity test over the hadith text's every
character. Two copies of a folding rule are two things to keep in step, and the
failure when they drift is silence rather than an error.

### The retired scripts

`Tools/CorpusBuilder/build_quran_db.py` and `build_tafsir_db.py` built the files
the app read before the migration, `quran.sqlite` (an older schema: `verse`,
`verse_fts`, `source`, …) and `tafsir.sqlite`. Their downloads, pins and checks were
ported into `Tools/QuranBuilder` at M2 and the scripts were deleted at M3, when the
new files replaced the old; git history has them.
