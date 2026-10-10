# QuranBuilder

Builds the Quran database, its packs and the curated ayah list the app reads, from one of two input
profiles that write **one schema**. Ported from Mushaf's `BuildQuranData`; see
`QURAN_MIGRATION_PLAN.md` (T3, T4, T6, T14, T15, T16) for why it is shaped this way, and
`ThawabForGod/Resources/Corpus/README.md` for the sources, their licences and the rules the data is held to.
Not part of the app target.

```sh
# from the repository root
swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile tanzil
swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul    # needs QuranData/raw
swift test --package-path Tools/QuranBuilder
```

| Profile | Inputs | Writes | In git? |
| --- | --- | --- | --- |
| `tanzil` | Tanzil's Uthmani and Simple Clean texts and `quran-data.xml`, downloaded once into `QuranData/raw/tanzil/`; Tafsir al-Jalalayn from the `spa5k/tafsir_api` mirror, into `QuranData/raw/jalalayn/` | `QuranData/out/tanzil/quran.sqlite`, `Packs/tafsir-ar-jalalayn.sqlite`, `ayah-of-the-day.json`; installs the database and the pack into `ThawabForGod/Resources/Corpus/` | **Yes**, the installed copies |
| `qul` | The Quranic Universal Library downloads in `QuranData/raw/` (git-ignored), each verified against `QuranData/SOURCES.md` | `QuranData/out/qul/quran-mushaf.sqlite`, `Fonts/` (QUL header, surah-name and juz-name faces), `Packs/` (Saheeh International, Al-Muyassar, Al-Mukhtasar, surah info), `ayah-of-the-day.json`; the 604 page fonts into `QuranData/Fonts/madaniV2/`; installs the database and packs into `ThawabForGod/Resources/Corpus/` and the three faces into `ThawabForGod/Resources/Fonts/Quran/` | **Never.** QUL publishes no licence; the installed copies are git-ignored by name |

Profiles live in `profiles/<name>.json`; paths in them are relative to that folder. Every output is
written under `QuranData/out/` (git-ignored), except the page fonts, whose folder the app target
references (`Tools/add_quran_data_phase.rb`). Once every check and the size budget have passed, the
profile's `install` section copies the outputs into the app's resources (`Install.swift`), so a failed
build never replaces what the app has. Whether a copy is committed is the `.gitignore`'s decision, by
file name: the tanzil database and the Jalalayn pack are; nothing from qul is.

## What every build checks

- **Pins.** Tanzil's two texts are pinned by the SHA-256 of their verses (not of the files, whose copyright
  block carries the year), Jalalayn by the SHA-256 of its notes and by its 226 silent ayahs, and every QUL
  input by its file hash in `SOURCES.md`. A change upstream stops the build; re-pinning is a decision.
- **The whole Quran.** 114 surahs, 6,236 ayahs in canonical order, every ayah with text, 15 sajdahs, juz
  boundaries equal to `StaticTables.juzStarts`, and every capability a profile claims actually filled.
- **The size budget** (T6): everything the profile will put in the app, measured per file and deflated,
  against 200 MB compressed and 400 MB installed. Over budget fails the build.

## The schema

`QuranSchema` in `Sources/QuranBuilder/QuranSQLiteWriter.swift` — Mushaf's schema 3, unchanged, plus
`meta.profile` and `meta.capabilities`. A profile that lacks something leaves its tables empty and leaves
it out of `capabilities`, so the app asks `meta` one question instead of probing tables:

| Capability | Tables | tanzil | qul |
| --- | --- | --- | --- |
| `text` | `surah`, `ayah`, `ayah_fts` | ✓ | ✓ |
| `words` | `word` | | ✓ |
| `mushafPages` | `mushaf_line`, `mushaf_page`, `marker` | | ✓ |
| `glyphV2` | `word.glyph_v2` | | ✓ |
| `fontLigatures` | `font_ligature` | | ✓ |

`ayah_fts` holds `text_norm` (the search text folded by `Packages/ArabicText`'s `ArabicNormalizer`, the
same fold the app applies to every query) and `text_stem` (the stems of words with attached particles,
`ArabicPrefixStemmer`; Quran only).

Packs (`Packs.swift`, pack schema 2): one sqlite per edition, named `translation-<id>`, `tafsir-<id>` or
`surah-info-<id>`. Each describes itself in its `pack` table, in English and Arabic, so the app finds packs
by prefix with no manifest. The build's manifest is a report in `QuranData/out/reports/`, never bundled.

## Tests

`Tests/QuranDataIntegrityTests`: Mushaf's suites (layout, metadata, text against the fonts, search,
ligatures, page fonts, packs, sanitizer, size report, curated list) against the qul output; `TanzilProfile`
against the database the app ships today (text byte for byte, divisions, sajdahs, every verse's search fold,
the same verses for the same queries); `ProfilesAgree`; `JalalaynPack` (the 226 silent ayahs, every note
byte for byte); `PackDiscovery`; `TanzilInstalled` and `QULInstalled`, that what the app bundles is what
the build wrote. The "same as before" checks compare against `PreMigrationCorpus`: fingerprints of the
`quran.sqlite` and `tafsir.sqlite` the app shipped before M3, taken from those files just before M3
replaced the one and deleted the other. A suite whose profile has not been
built is skipped with the reason — a public clone builds and tests `tanzil` alone.

## Findings (reported, not altered)

The builds print these as `finding:` lines. Kept from Mushaf, for the QUL data:

- **Short pages:** pages 1 and 2 have 8 lines (decorated opening pages); every other page has 15.
- **Surah header at page bottom:** on 18 pages the header is the last line and the basmala opens the next
  page: 76, 207, 331, 341, 349, 366, 376, 414, 417, 445, 452, 498, 506, 525, 548, 555, 557, 584.
- **Line-initial ayah markers:** 573 text lines begin with the previous ayah's end marker (e.g. 2:45 on
  page 7, line 12), confirmed against Quran.com's QCF V2 line numbers.
- **Mid-page juz starts:** juz 4, 7, 11 and 26 begin mid-page (pages 62, 121, 201, 502). A page is labelled
  with the juz of its last ayah, which gives the standard juz start pages.
- **Empty strings in the layout:** `first_word_id`, `last_word_id` and `surah_number` are `''`, not NULL,
  where they do not apply. Stored as NULL.
- **Arabic surah names:** QUL — and Tanzil, identically — spell six names without the hamza of the printed
  headers: 14 ابراهيم, 34 سبإ, 76 الانسان, 78 النبإ, 82 الإنفطار, 84 الإنشقاق. Both profiles keep the
  static table's printed spellings.
- **Spaces inside words:** 209 QUL script words contain a space (۞ before, ۩ after, and إِلۡ يَاسِينَ at
  37:130:3, which QUL's ayah metadata counts as two words — its one word-count difference).
- **Sajdah types:** QUL gives `optional` (11) and `required` (4). Tanzil's `recommended` and `obligatory`
  name the same fifteen verses with the same four obligatory, and are stored in QUL's words.
- **Ligatures:** 113 of 114 `surah-header` values end in a space (trimmed). In `surah-name-v2.ttf` the
  Al-Ahzab rule matches `033` rather than `surah033`; it still draws correctly.
- **Translation and tafsir packs:** Saheeh International agrees with QUL's simple export on all 6,236 ayahs
  (1,904 footnotes). Al-Muyassar has 5,040 groups, Al-Mukhtasar 6,216, every group contiguous and in one
  surah. The sanitizer's changes are printed per pack. Al-Mukhtasar has four stray combining marks and two
  typographic slips (4:66, 3:4), kept as given.

New with the tanzil profile:

- **Divisions:** Tanzil and QUL agree on every juz, hizb, manzil and sajda. They differ on one rub el hizb
  (quarter 106 begins at 15:49 in QUL, at 15:50 in Tanzil) and on the rukus (556 against 558, so the ruku
  numbers diverge after the first split they place differently). Each profile stores its own source's.
- **Revelation:** Tanzil and QUL agree on all 28 Madinan surahs.
- **Basmala:** Tanzil carries it as a prefix of verse 1 of 112 surahs; the build lifts it off, exactly as
  `build_quran_db.py` (retired at M3) did, so verse text is byte-identical to what the app shipped before.
- **Jalalayn:** 77 of its 6,010 notes run to more than one paragraph; the line breaks are kept as `<br>`.
