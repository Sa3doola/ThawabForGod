# Quran migration plan: Mushaf → Noor (ThawabForGod)

Status: **decisions locked 2026-10-10; M0 and M1 done; M1 questions answered (see `docs/quran-migration/MAPPING.md` §7).**
Source project (read-only reference): `~/Desktop/Untitled Project`, tag `mushaf-final`.
Target: this repo, branch `quran-migration`.

Goal: replace Noor's current Quran section with the Quran engine and features built in Mushaf: a page-exact Madani V2 Mushaf plus separated mode, translation and tafsir packs, search, library, bookmarks, notes, highlights, widgets, and iPhone Duo and Mac polish. This is a **port, not a copy**: Mushaf code is rewritten to this repo's `CLAUDE.md` conventions.

---

## 1. Decisions (locked)

| # | Decision |
|---|---|
| **D1 Data and licensing** | **Option A.** Port everything. Anything derived from QUL (Mushaf layout and glyph codes, V2 page fonts, QUL header, name and common fonts, Saheeh/Muyassar/Mukhtasar packs) is **built locally from the git-ignored `QuranData/raw/` and never committed**: the repo is public and MIT, and QUL publishes no license. The public repo builds a **Tanzil fallback** (separated mode, Tanzil text, Jalalayn). App Store builds ship the full Mushaf only once the license answers are in hand. |
| **D2 Existing users** | **None.** Noor isn't on the App Store, so old Quran user data isn't migrated; the old records are just replaced. |
| **D3 Scope for v1** | **In:** bookmarks, notes, highlights, search, library (surah/juz/hizb/page), widgets (Continue Reading, Ayah of the Day), iPhone Duo, Mac Quran menu. **Out:** khatmah (removed), `.quranbackup`, multi-window. |
| **D4 Reading settings** | **Mushaf's reading settings replace Noor's** (Paper / Sepia / Dark reader themes, follow system, Mushaf/separated mode, separated text size, translation under ayah, margin markers, landscape and fold options). **Kept from Noor:** **Keep screen awake** (`keepScreenAwake(_:)`), and **Amiri Quran (OFL) as a separated-mode font option**. **Removed:** Noor's `ReaderPaper`/`ReaderTypography` reader settings, the verse-number toggle, AyahMarker 1–12 and SurahNames.ttf (unlicensed). Digits are **Noor's app-wide `NumberSystem`**; Mushaf's own numeral setting is dropped. |
| **D5 Mushaf app** | **Frozen** at tag `mushaf-final`, backed up to a private repo. It's the reference; it's never modified. |

## 2. Technical traps and their fixes

| # | Trap | Fix | Lands in |
|---|---|---|---|
| T1 | `Core/Theming/FontRegistrar` registers **every** bundled `.ttf` at launch, so 604 V2 fonts would be registered before the first frame. | The walker skips the V2 page-font folder. Mushaf's `FontPackStore` (current page ±3, release beyond 20) owns those fonts. Small faces (Hafs, QUL header/name/common, Amiri) still register at launch. `FontRegistrarTests` asserts no `QCF2*` face is registered at launch. | M2 |
| T2 | The 64-notification cap. | **Removed with khatmah.** If khatmah ever returns: one repeating slot only (prayer reminders use 50). | — |
| T3 | Three Arabic normalizers (Python builders, `Core/Search/ArabicSearchQuery`, Mushaf's `QuranText`) that differ in how they strip marks. Drift breaks search silently. | One Swift implementation in a local package `Packages/ArabicText` (from Mushaf's `QuranText`, reconciled with `ArabicSearchQuery`'s rules), used by `Core/Search` **and** `Tools/QuranBuilder`. The Python hadith builder keeps its own `normalize()` plus a parity test over a fixed word list. **Particle/stem matching is Quran-only in v1;** hadith search is unchanged. The package is added through an idempotent `Tools/*.rb` script (xcodeproj gem), never by hand. | M2 |
| T4 | Two pipelines; the public build vs the full build. Mushaf's screens expect Mushaf's schema. | **One Swift builder, `Tools/QuranBuilder`** (ported from `BuildQuranData`, with its SHA checks and tests), **two input profiles, one schema:** `tanzil` → `Resources/Corpus/quran.sqlite` (**committed**: no layout or glyph tables, `meta.capabilities` without `mushafPages`); `qul` → `quran-mushaf.sqlite` + packs + V2 fonts (**git-ignored**). The app prefers `quran-mushaf.sqlite` when bundled and reads capabilities from `meta`, hiding Mushaf mode in the fallback. **Release builds fail** if the full data is missing; Debug builds and public clones build without it. Jalalayn becomes a tafsir pack (committed: public domain). `build_quran_db.py` and `build_tafsir_db.py` are retired once their Tanzil download and verification steps are ported. | M2 |
| T5 | Widgets can't open a corpus (`Shared/` rule, memory budget) and draw in the system face, which mangles Uthmani text. | The app publishes the day's ayah and the reading position into the App Group (`SharedDefaults`). The Hafs font is copied into the App Group container and registered by the widget (as in Mushaf 6.7). Two **new** widget kinds; existing prayer widget kinds are untouched. **`DeepLink` gains `quranVerse` and `quranPage` cases** (additive; existing links keep resolving). | M7 |
| T6 | Size: about 30 MB → about 175 MB with the full data. | Port Mushaf's size report into `QuranBuilder` (budget 200 MB compressed). GitHub is unaffected because the large files are git-ignored. | M2, M8 |
| T7 | `AppRoute.quranVerse(VerseReference)`, `RecentActivity` subjects `"s:v"` and installed links must keep working. | Mushaf's `AyahID` is **renamed to Noor's `VerseReference`** during the port. One name for one concept, and existing routes and rows still resolve. | M3 |
| T8 | Duplicate type names (`Surah`, `Juz`, verse types) in one module mean the old and new features can't coexist. | **Delete the legacy Quran feature at M3.** On the branch the Quran tab shows a placeholder until M5. Acceptable: there are no users and the branch isn't shipped. | M3 |
| T9 | Mushaf's reader palettes are literal RGB; Noor forbids literal colours in views. | Paper / Sepia / Dark become named colour sets in the shared asset catalog, read through `AppColor`/`Theme`. Highlight colours are the same. | M4 |
| T10 | About 214 Mushaf user-facing strings. | Every one becomes an `L10nKey` case with ar + en in `Localizable.xcstrings`; the existing both-languages test guards it. Done by the `l10n-porter` subagent, reviewed by the main agent. | M4, M5 |
| T11 | Mushaf was full-screen; in Noor it lives inside a tab (iPhone) or the split view's detail column (iPad/Mac). | Immersive mode also hides the **tab bar**. Page-unit rules use the detail column's size, so spreads fit beside the sidebar. Mac Quran commands (⌘F, ⌘G, ⌘D, ⌘T, ⌥⌘I, ⌘[ ⌘], arrows) are active **only while the Quran section is focused** (focused scene value), so they never clash with Hadith or with `SectionCommands` ⌘1–4. | M5, M7 |
| T12 | Mushaf measures the fold itself (`MushafFold`); the adhkar reader does not measure it at all, it hands the split to the system's `ArrangementView`. | **One helper, one caller:** `MushafFold` becomes `Core/Layout/FoldGeometry`, used by the Quran reader; the adhkar keeps `ArrangementView`. | M4 (moved), M7 (Duo panel, tabletop) |
| T13 | Language mode: Noor is Swift 5 mode with MainActor-default isolation; Mushaf is Swift 6. | Keep every `nonisolated`/`actor`/`@concurrent` exactly as in Mushaf. Measurement, DB and font work stays off the main actor. Run the `SWIFT_VERSION=6.0` check only as advisory (it crashes the compiler today; see `CLAUDE.md`). | M3–M5 |

## 3. Milestones

Each milestone is one Claude Code run that stops for review. Every task builds clean (warnings count) on the **iOS simulator and macOS**, all tests pass, and there's one commit per task (`Quran migration Mx.y: …`).

| # | Milestone | Tasks | Done when |
|---|---|---|---|
| **M0** | Prep | Create the branch. Delete the stray `ReadingView.swift` and the empty `Tools/MushafBuilder`. Copy Mushaf's `QuranData/raw/` into `QuranData/raw/` and **git-ignore** it, plus the generated full-data outputs (`quran-mushaf.sqlite`, QUL packs, V2 font folder). Confirm `git status` lists none of them. | Branch builds; nothing changed functionally |
| **M1** | Mapping | `docs/quran-migration/MAPPING.md`: every Mushaf file → port / adapt / replace-with-Noor-equivalent / drop, with the destination; every Noor Quran file and touch point → keep / replace / delete; the concept map; each trap with its exact files. Produced by parallel `migration-scout` subagents and consolidated by the main agent. **No code changes.** | Saad has reviewed the mapping |
| **M2** | Data (outputs to `QuranData/out/` only; the app keeps today's corpus until M3) | `Packages/ArabicText` + parity test (T3); `Tools/QuranBuilder` with `tanzil` and `qul` profiles (T4); Jalalayn, Saheeh, Muyassar, Mukhtasar and surah info as packs; V2 fonts as a git-ignored folder reference added by a `Tools/*.rb` script; the `FontRegistrar` exclusion (T1); the Release guard; the size report (T6); the Corpus README rewritten for the new sources. | Both profiles build valid DBs; data tests green; hadith search unchanged |
| **M3** | Domain and Data | Delete the legacy Quran feature (T8) and put a placeholder in the tab. Port Mushaf's Domain and repositories under `Features/Quran/Domain` and `Data` behind protocols, reading through `CorpusDatabaseProviding`, with `AyahID` → `VerseReference` (T7). Unit tests ported by `test-porter`. | Unit tests green on iOS + macOS |
| **M4** | Rendering and reading settings | Page renderer (`JustifiedLineLayout`, `PageMetricsCache`, `FontPackStore`, pager, spreads) under `Features/Quran/Mushaf`. Reader themes as assets (T9). D4 settings via `SettingsKey`s, including keep-awake and Amiri. Digits via `LocalizationManager`. Strings → `L10nKey` (T10). Golden pages rendered. | Golden pages match `mushaf-final` on iPhone SE, iPad, Mac; memory flat paging 1→604 |
| **M5** | Screens and navigation (switch-over) | Library (surah/juz/hizb/page) + continue reading as the Quran tab root; Mushaf and separated modes; ayah panel (translation/tafsir, sheet or inspector); search; reader settings sheet. All through `QuranCoordinator` typed paths + `AppRoute`. Fallback mode hides Mushaf mode cleanly. Immersive mode hides the tab bar (T11). | The tab runs on the new engine in both data modes; the Tanzil fallback hides Mushaf mode **and the Library's Page tab** (its page breaks differ from V2 for 56 verses), keeping Juz and Hizb; search highlights matches (Mushaf's behaviour kept); old routes and recent-activity rows open the right ayah |
| **M6** | User data | Bookmarks, notes and highlights as `@Model`s in `PersistenceController.schema` via `@ModelActor` repositories; uniqueness in the repository (iOS 17); old `QuranBookmarkRecord`/`ReadingPositionRecord` replaced. Home's continue reading and `RecentActivity` wired. | CRUD + UI tests green |
| **M7** | Platforms and widgets | Mac Quran menu scoped to the focused section (T11); keyboard paging on iPad/Mac; iPhone landscape rules; the Duo panel and tabletop on `FoldGeometry` (T12); Continue Reading + Ayah of the Day widgets with the curated list, the App Group font and the new `DeepLink` cases (T5). | Screenshots on iPhone, iPad, Duo, Mac; widgets render |
| **M8** | Cleanup and release check | Remove leftovers (old records, unlicensed fonts, retired Python builders). Update `CLAUDE.md` (Quran section), `ARCHITECTURE.md`, `README.md` sources table, Corpus README, `Resources/Licenses`. Size report, offline proof, full UI + unit suites on iOS and macOS. | No `TODO(license)`; ready to merge |

Rough effort: **8–10 sessions.**

## 4. How the sessions use subagents (Opus · Sonnet · Haiku)

Agent definitions are written in `docs/quran-migration/agents/` and copied to `.claude/agents/` (the two folders stay identical). Each file's `model:` decides the model; **the main agent never passes a model override**, and `CLAUDE_CODE_SUBAGENT_MODEL` stays unset. The main session runs on **Opus** (`/model opus`): it orchestrates, resolves build errors, and is the only one that builds, tests and commits.

| Subagent | Model | Used for | Never does |
|---|---|---|---|
| `quran-architect` | **opus** | Design note per task: types, isolation, data flow, navigation, disjoint batches with exact interfaces, test plan, risks → `docs/quran-migration/design/<task>.md` | Write app code, build |
| `quran-reviewer` | **opus** | Independent review of the staged diff: correctness, concurrency, rendering, data safety, rules → Blocking / Should fix / Later | Edit, build, any git command that writes |
| `feature-implementer` | **sonnet** | One batch of views / view models / coordinator wiring / ports, only its listed files; strings as literals marked `// L10N-TODO` | Touch files outside its batch, add `L10nKey`s, build |
| `ui-test-writer` | **sonnet** | XCUITest flows and screenshot scripts from the design note | Edit app code (reports missing identifiers instead) |
| `migration-scout` | haiku | Read-only inventories → a table | Edit, build |
| `l10n-porter` | haiku | `L10N-TODO` lines and literals → `L10nKey` + ar/en | Change logic or layout |
| `test-porter` | haiku | Port Mushaf unit tests; write the unit tests the design note lists | Change app code to pass a test |
| `rules-checker` | haiku | Mechanical scan of the staged diff (QUL files, Quran data, pbxproj, literals, `UserDefaults`, `#if os`, `print`) | Judge design, edit |

**Every task runs this pipeline**, so all three models work on every task:

1. **Design (Opus)**: `quran-architect` writes the design note. The main agent checks it and sends any open decision to Saad in the stop report (or decides if it's reversible and says so).
2. **Scout (Haiku, when porting)**: `migration-scout` on the Mushaf folders the note names, in parallel.
3. **Implement (Sonnet)**: one `feature-implementer` per batch, **in parallel**, batches share no file.
4. **Localize (Haiku)**: `l10n-porter` on the changed files, split into disjoint batches if there are many.
5. **Build (main)**: iOS simulator + macOS, zero warnings. The main agent fixes build errors itself; a fix bigger than a few lines goes back to the batch's implementer.
6. **Tests (Haiku + Sonnet, parallel)**: `test-porter` for unit tests, `ui-test-writer` for UI flows; then the main agent runs both suites on iOS and macOS.
7. **Gate (Haiku → Opus)**: stage the change, `rules-checker` first; once it passes, `quran-reviewer`. Blocking and Should-fix items are fixed (back to step 5); Later items go in the stop report.
8. **Commit (main)**: `Quran migration Mx.y: …`, with a body line `Agents: architect(opus) · implementer×N(sonnet) · ui-test-writer(sonnet) · l10n-porter(haiku) · test-porter(haiku) · rules-checker(haiku) · reviewer(opus)` listing what actually ran.

A tiny task (a one-file fix) may use a three-line design note and skip step 2 and the UI tests, but never skips steps 1, 4, 7. Rules: parallel subagents only on disjoint files; **only the main agent runs `xcodebuild`** (parallel builds fight over DerivedData); subagents can't start subagents, so the main agent runs every step. Design notes are committed with their task.

### Lean mode (current, from M5.2a, 2026-10-11)

The full pipeline used most of a week's usage in M5.0-M5.2, mostly on 400-1,000-line design notes and simulator test/screenshot runs. Until Saad switches it back:

- **Main session on Sonnet** (`/model sonnet`). Opus is used only through `quran-architect` and `quran-reviewer`.
- **Per task:** architect (opus, note ≤ 120 lines) → at most 3 `feature-implementer`s (sonnet) → `l10n-porter` (haiku) → **build only** (iOS simulator + macOS; no test runs) → `rules-checker` (haiku) → `quran-reviewer` (opus, ≤ 40 lines, one pass; a second pass only if it found Blocking items) → commit.
- **Skipped:** `test-porter`, `ui-test-writer`, running unit or UI tests, screenshots, golden pages. **Saad tests** from the checklist in each design note and reports back. `migration-scout` only for a Mushaf folder not inventoried yet.
- Build output is filtered (`xcodebuild … -quiet 2>&1 | grep -E "error:|warning:" | head -40`) so logs don't fill the context.
- Small fixes (one or two files) skip the architect and go straight implement → build → rules-checker → reviewer.
- The commit body keeps the `Agents:` line and adds `Tests: not run (lean mode); Saad's checklist in design/<task>.md`.
- Tests that no longer compile after a change are fixed by the main agent only if the app target's build needs it; otherwise they're listed for Saad's test pass.

## 5. What Saad does

1. Review each milestone's stop report and screenshots before starting the next.
2. Keep the license requests going (`~/Desktop/Untitled Project/docs/release/license-requests.md`); they decide what the App Store build ships.
3. Test on devices at M5 and M8: iPhone, iPad and Mac, plus a Duo if available.
4. Merge `quran-migration` into **`Development`** only after M8 (the branch was cut from `Development`; `main` follows `Development`).
