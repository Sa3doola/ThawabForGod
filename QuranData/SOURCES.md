# Quran data sources

All inputs come from the Quranic Universal Library (https://qul.tarteel.ai, free account), downloaded 2026-10-02.
Raw files live in `QuranData/raw/` (git-ignored; keep a zip backup). Check them with:
`cd QuranData/raw && shasum -a 256 -c <(grep -E '^[0-9a-f]{64}  ' ../SOURCES.md | sed 's/  `/  /;s/`$//')` and `shasum -a 256 -c ../fonts-v2.sha256`.

License status: QUL says licensing is per resource. **Every row is `unconfirmed` until you have it in writing** (QUL Discord / GitHub issues, or the original publisher). The release view of these rows (publisher, terms, whom to ask, fallbacks) is `docs/release/LICENSES.md` (Phase 8.1), with draft requests in `docs/release/license-requests.md`.

## Bundled in the app today (`Mushaf/Resources/Fonts/`)

Check with `shasum -a 256 Mushaf/Resources/Fonts/*.ttf`. Copyright and license text below are quoted from each font's own `name` table (read 2026-10-02). The three QUL fonts are copied from `QuranData/raw/fonts/headers/` by `BuildQuranData` (listed in `build.json` → `fonts`), which checks their hash before and after the copy.

| Font file | PostScript name | Source | SHA-256 | License status |
|---|---|---|---|---|
| `KFGQPC-HafsUthmanic.ttf` (byte-identical to QUL `UthmanicHafs_V22.ttf` below) | `KFGQPCHAFSUthmanicScript-Regula` | KFGQPC, http://fonts.qurancomplex.gov.sa/ (via QUL) | aa68bffce289b4c0ebac68e90502eb69e42356abcd1603cb2b8e99c2c723f145 | **OK to ship.** Embedded KFGQPC EULA: free to use, copy and distribute; must not be sold or modified |
| `surah-header.ttf` (QUL, copied by the pipeline) | `QCF_SurahHeader_COLOR` | QUL `fonts/headers/surah-header.ttf` (below) | 731cdc14a3e50669ffd44c06335ce269665e22cb75db39ca137527e29c516308 | unconfirmed (QUL), like every QUL row below. Mushaf header lines since Phase 2.1 |
| `surah-name-v2.ttf` (QUL, copied by the pipeline) | `surah-name-v2` | QUL `fonts/headers/surah-name-v2.ttf` (below) | 2d4678ef53ef76c361c32c13a9ad26317b8f8219089ab5822aafa6ed5d17502a | unconfirmed (QUL). Surah list and separated-mode banner since Phase 2.1 |
| `quran-common.ttf` (QUL, copied by the pipeline) | `quran-common` | QUL `fonts/headers/quran-common.ttf` (below) | 63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa | unconfirmed (QUL). Registered; juz names available for page chrome |

Removed in Phase 2.5: `AyahMarker-1.ttf` ("ayat quran 1", quranb1og.blogspot.com, sha eb3bfcf5…1b0c, no license terms). Unicode-mode ayah markers are now the marker words' Arabic-Indic digits, which KFGQPC Hafs draws as its own ornamented end-of-ayah glyph (all 286 numbers, tested). No bundled font is left with an unresolved `TODO(license)`; the QUL rows stay `unconfirmed` until QUL confirms in writing.

Removed in Phase 2.1: `SurahNames.ttf` ("Quran karim 114", elharrakfonts.com, sha b29797d2…f672, all rights reserved, no redistribution grant). Its hard-coded character table (`SurahNameGlyph.scalars`) is gone too; the surah header and name lookups are generated from the QUL ligature JSON into `quran.sqlite` (`font_ligature`).

## Bundled content packs (`Mushaf/Resources/Packs/`)

Built by `BuildQuranData` from the translation rows below (`build.json` → `packs`); file hashes and sizes are in `Packs/manifest.json`.

| Pack | File | Source | License |
|---|---|---|---|
| Saheeh International (en), 6,236 ayahs, 1,904 footnotes | `Packs/translation-en-sahih-international.sqlite` | QUL translation 193 (footnote tags) | **unconfirmed** (Saheeh International / Al-Muntada); attribution shown under every translation and in Settings → Sources |

## Mushaf (Madani V2, 1421H)

| Resource (QUL) | File | SHA-256 | License |
|---|---|---|---|
| KFGQPC V2 layout (1421H print): 604 pages, 15 lines, 9046 rows | `layout/qpc-v2-15-lines.db` | e4df98f35dd3b8927ff096337c8739e0f0b12c8ba622834c345eaa4c3e28dd8c | unconfirmed (KFGQPC) |
| KFGQPC Hafs script: word by word (83,668 entries = 77,432 words + 6,236 markers) | `script/qpc-hafs-wbw.json` | f366269234e24f322146c043fe5fbf0132990613a94aff4b3f23847f45793ea7 | unconfirmed (KFGQPC) |
| QPC V2 Glyph: word by word (same keys and ids as Hafs WBW, verified) | `script/qpc-v2-glyph-wbw.json` | 40964a1b7932e9a69e0dfc0d58dce3b73e30a803febda119fd6828bcb75fac98 | unconfirmed (KFGQPC) |
| QPC V2 Glyphs: ayah by ayah (has `page_number`) | `script/qpc-v2-glyph-ayah.json` | 53ffaeb5e35fb25a272a74421793e9e0c0ea0ccdc6b0d28c05413898c023c3c9 | unconfirmed (KFGQPC) |
| QPC V2 Font: 604 files `p1.ttf…p604.ttf`, PostScript `QCF2001…QCF2604`, 208 MB. Copied by the pipeline into `Mushaf/Resources/Fonts/madaniV2/` (git-ignored), each file checked against the manifest | `fonts/v2/` | see the manifest row below | unconfirmed (KFGQPC) |
| Manifest of the 604 V2 font hashes (`QuranData/fonts-v2.sha256`, path relative to `raw/`) | `../fonts-v2.sha256` | a1316f4af85f2c049b0fef2b863d784c68a46ffa43a3f6034d85fbff53bb7229 | — |
| QPC Hafs font `UthmanicHafs_V22.ttf` (byte-identical to the bundled `KFGQPC-HafsUthmanic.ttf`) | `fonts/UthmanicHafs_V22.ttf` | aa68bffce289b4c0ebac68e90502eb69e42356abcd1603cb2b8e99c2c723f145 | KFGQPC: free to distribute, no sale or modification |
| Surah header font: PostScript `QCF_SurahHeader_COLOR`; one glyph = full header per surah | `fonts/headers/surah-header.ttf` | 731cdc14a3e50669ffd44c06335ce269665e22cb75db39ca137527e29c516308 | unconfirmed |
| Surah header ligatures (`surah-N` → code point, values have a trailing space) | `fonts/headers/surah-header-ligatures.json` | c4480a1fb616685421ada1f9cbd36187c1c27c01d8d78d27a866858fdaf5c4f7 | — |
| Surah name font v2: PostScript `surah-name-v2` | `fonts/headers/surah-name-v2.ttf` | 2d4678ef53ef76c361c32c13a9ad26317b8f8219089ab5822aafa6ed5d17502a | unconfirmed |
| Surah name v2 ligatures (`surah-N` → `surahNNN` ligature string) | `fonts/headers/surah-name-v2-ligatures.json` | 913095159d6d8f82d93dab653271f9ed321545d8350f3d8f3009bfce3c3592aa | — |
| Juz name font: PostScript `quran-common` (also has header frame, makkah/madinah icons) | `fonts/headers/quran-common.ttf` | 63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa | unconfirmed |
| quran-common ligatures (72: `juz-N-name` → `jNNN`, …) | `fonts/headers/quran-common-ligatures.json` | 2f94eb3da80d0b4e423c5b3bb2634376379fe1eb05aa042df36eb82b02adae59 | — |

## Text, metadata, info

| Resource | File | SHA-256 | License |
|---|---|---|---|
| Imlaei simple: ayah by ayah (no diacritics, for search) | `script/imlaei-simple.json` | 7219ed83c82359d472d3e82e234b0f45071298a18e07e985b80ea363e9d6d364 | unconfirmed |
| Metadata: ayah (6236) | `metadata/quran-metadata-ayah.json` | bf1e0d24abf378acc7ebd35c4ecbcbf941057594fefa50322cc5c801565de0f4 | unconfirmed |
| Metadata: juz (30) | `metadata/quran-metadata-juz.json` | 0e34f5abbd786c828d388b1f3c732db8b42b1bf36a4f619603e4c632f9e86628 | unconfirmed |
| Metadata: hizb (60) | `metadata/quran-metadata-hizb.json` | 6a99e08337fc3629b3c0ae04897cbdd33c818fea94ff01d1be8aa33a80e2cb64 | unconfirmed |
| Metadata: rub (240) | `metadata/quran-metadata-rub.json` | 9a8b17d69a3c173bff92aae5d53f6f83829cc8f513514b82266c4e4a3f81fd38 | unconfirmed |
| Metadata: manzil (7) | `metadata/quran-metadata-manzil.json` | 6526ccc89ab04e4f2e8a1476095bc5cce864199f59ceb75da57f29e176cce60d | unconfirmed |
| Metadata: ruku (558) | `metadata/quran-metadata-ruku.json` | f2ae81482e284df653de921f353f6c4d49d19a6c707768f6459022d6a8a3084a | unconfirmed |
| Metadata: sajda (15) | `metadata/quran-metadata-sajda.json` | 5b7a7859b57b03387b9b58fd46dfdcb3792b61cad5e982f0295ac29603958988 | unconfirmed |
| Metadata: surah names (114, revelation order and place) | `metadata/quran-metadata-surah-name.json` | ada09f674efd35d0c054c9b81c98d14550f6c66b77767a9173674799f675d7de | unconfirmed |
| Surah information: English (HTML) | `surah-info/en.json` | 8e34712118186458a71e8b3c815e5954dbc20fb65dbbbf0ba76ae7350c8c7a03 | unconfirmed |

## Translations and tafsir

| Resource | File | SHA-256 | License |
|---|---|---|---|
| Saheeh International (en): simple ([QUL translation 193](https://qul.tarteel.ai/resources/translation/193)); used to cross-check the footnote version | `translations/en-sahih-international/en-sahih-international-simple.db` | 198e108f4e9252f3d14300f920e5a6c6a4f0bbc43aef9cf2451f2ca52ce6068a | unconfirmed (Saheeh International / Al-Muntada) |
| Saheeh International (en): footnote tags (`t` + `f`); source of the bundled pack | `translations/en-sahih-international/en-sahih-international-with-footnote-tags.json` | 7cbed343434258ed8d66aa5481ab0b9ee09ba81e97884e1bc10837db48a5fedc | same |
| Tafsir al-Muyassar (ar): 6236 rows, 5040 groups, HTML | `tafsir/ar-muyassar/ar-tafsir-muyassar.db` | 73a405b933a33039affe96af05bd3cc82f4967f1372dccc797a8b2408cd9b916 | unconfirmed (KFGQPC) |
| Abridged Explanation of the Quran (en, Al-Mukhtasar) | `tafsir/en-mukhtasar/abridged-explanation-of-the-quran.db` | 60b520c67260e35f83c16fc34f526a7a85c39392a642808f4d85725e968e291c | unconfirmed (Tafsir Center) |

Tafsir packs bundled since Phase 4.1/4.5: `Mushaf/Resources/Packs/tafsir-ar-muyassar.sqlite` and `tafsir-en-mukhtasar.sqlite`, converted from the two files above (`build.json` → `packs.tafsirs`; sanitizer report and findings in `Scripts/BuildQuranData/README.md`). Both licenses are **unconfirmed** and must be resolved before release (roadmap 8.1). The exact QUL resource pages (ids) for these two downloads are not recorded yet: the packs' `source_url` is QUL's tafsir index.

## Curated by this project

| Resource | File | Bundled as | License |
|---|---|---|---|
| Ayah of the day list (Phase 8.0): 125 entries (single ayahs and ranges) chosen by this project, each with a note; **draft, to be reviewed by Saad** | `QuranData/curated/ayah-of-the-day.txt` (in git; its SHA-256 is recorded in the JSON) | `Mushaf/Resources/ayah-of-the-day.json` (references only; the text comes from `quran.sqlite` and the packs) | Own work; no third-party content |

## Findings from verification (2026-10-02)

- Layout `first_word_id` / `last_word_id` are **empty strings `''`, not NULL** on `surah_name` / `basmallah` rows. Treat `''` as absent.
- `surah-header.ttf` (`QCF_SurahHeader_COLOR`) draws the **complete header (frame + name)** with one glyph per surah. The hand-drawn `SurahBanner` and `SurahNames.ttf` can both be retired for Mushaf pages. `surah-name-v2.ttf` is for lists and titles.
- Ligature JSON values have a trailing space: trim them. (`surah-header-ligatures.json`: 113 of 114 values; the pipeline trims and reports it.)
- `surah-name-v2.ttf`: the ligature for Al-Ahzab is keyed on `033`, not `surah033`, so "surah033" shapes as five empty zero-width glyphs plus the name glyph. It draws correctly; the integrity tests pin it (`expectedMultiGlyphSurahNames`).
- V2 glyph codes (`qpc-v2-glyph-wbw.json`) are Arabic Presentation Forms-A characters (U+FB50–U+FDFF), 1–3 per word (79,154 single, 4,510 double, 4 triple), not private-use code points. They are only meaningful in their page font.
- `surah-header.ttf` is a COLR/CPAL colour font: the frame, ornaments and name are drawn in fixed print colours (green panel, gold, pink and teal borders, black name), whatever the text colour. Every glyph is 3.30 em wide and its ink 0.42 em tall.
- Tafsir sqlite columns: `ayah_key, group_ayah_key, from_ayah, to_ayah, ayah_keys, text`. Only the group owner has the text, and the text is HTML (`<div class=ar lang=ar><h3>…`).
- Not downloaded yet (Phase 3–4 packs): Surah info (ar), The Clear Quran, other languages, Ibn Kathir / Sa'di / Tabari, Ibn Kathir (en).
