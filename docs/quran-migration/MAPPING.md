# Quran migration — mapping (M1)

Status: **draft for Saad's review.** No code has changed in M1.
Inputs: `QURAN_MIGRATION_PLAN.md` (decisions D1–D5 and traps T1–T13 are final), eight `migration-scout` inventories, and direct checks by the main agent where a scout could not answer.
Reference project: `~/Desktop/Untitled Project` at **HEAD `5c1eae4`**, one commit past the tag `mushaf-final` (`3b3f17c`); that commit is the accessibility fixes and tests. The mapping follows HEAD, as instructed.

## How to read this

Path abbreviations used in every table:

| Short | Means |
|---|---|
| `Q/` | `ThawabForGod/Features/Quran/` (the new feature, rebuilt from the port) |
| `App/`, `Core/`, `Res/` | `ThawabForGod/App/`, `ThawabForGod/Core/`, `ThawabForGod/Resources/` |
| `Sh/` | `Shared/` (compiled into the app, the widget and the notification extension) |
| `QB/` | `Tools/QuranBuilder/` (new; from Mushaf `Scripts/BuildQuranData`) |
| `AT/` | `Packages/ArabicText/` (new; from Mushaf `Packages/QuranText`) |
| `T/`, `UIT/` | `ThawabForGodTests/`, `ThawabForGodUITests/` |
| `M:` | `Mushaf/` in the reference project |

Actions: **port** (move with only mechanical changes), **adapt** (rewrite to this repo's rules; behaviour kept), **replace** (an existing Noor type does the job), **drop**.

A scout's "suggested action" was overridden wherever it contradicted a locked decision. The scouts read `CLAUDE.md`'s "translations blocked on licensing", but D1 option A ports every pack and builds the QUL ones locally. Overridden: translations, surah info, highlights, `FontPackStore`, the `mushaf_*` tables and `ReaderTheme → ReaderPaper`. Every such row below follows the plan, not the scout.

### Target layout of the new feature

```
Q/
  Domain/            entities, protocols, pure logic (no SwiftUI)
    Markup/          TafsirDocument / TranslationDocument parsers (pure)
  Data/              GRDB corpus + pack repositories, search repository
    Fonts/           FontPackStore (actor), TextMeasurer
    UserData/        @Model records + @ModelActor repository          (M6)
  Mushaf/            page renderer, pager, page chrome                 (M4)
  Separated/         verse-by-verse reader                             (M5)
  Reader/            reader screen, view model, toolbar                (M5)
  AyahPanel/ AyahActions/ Tafsir/ Translation/                         (M5)
  Library/ Search/ Bookmarks/ Settings/                                (M5–M6)
  Platform/          Quran key commands, iPad/Mac input glue           (M7)
  QuranCoordinator.swift   typed path QuranRoute + sheet/panel state   (M5)
  QuranUserDataStore.swift @MainActor cache over the @ModelActor repo  (M6)
```

---

## 1. File map: Mushaf → ThawabForGod

### 1.1 `Mushaf/App` (5 files)

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `M:App/AppEnvironment.swift` | replace | `App/AppContainer.swift` | M3–M6 | Its service list becomes container properties. The DEBUG `UserDefaults` hook (:63) goes. |
| `M:App/AppRouter.swift` | adapt | `Q/QuranCoordinator.swift` | M5 | Sheet + ayah-panel state (`Sheet`, `AyahPanelSection`) becomes coordinator state next to a typed `QuranRoute` path. Backup/khatmah cases (:18–36, :93–97) dropped. |
| `M:App/MushafApp.swift` | replace | `App/ThawabForGodApp.swift` | M7 | Only the `.commands { ReaderCommands }` contribution moves (as `QuranCommands`, scoped per T11). Window/scene shape is Noor's. |
| `M:App/ReaderWindow.swift` | drop (split) | — | M5/M6/M7 | Multi-window is out (D3). `ReaderLocation` → `ReadingPosition` (M6). `onOpenURL` for `mushaf://` → `Sh/DeepLink` (M7). `.quranbackup` opening dropped. |
| `M:App/WidgetPublisher.swift` | adapt | `Q/Data/QuranWidgetPublisher.swift` | M7 | Writes through `SharedDefaults`/`SettingsStore` and reloads through `WidgetRefreshing`. The verse number at :77 goes through `LocalizationManager`. |

### 1.2 `Mushaf/Core` (28 files)

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `M:Core/Components/SurahHeaderGlyph.swift` | adapt | `Q/Mushaf/SurahHeaderGlyph.swift` | M4 | QUL header font; falls back to text in the Tanzil build. `.font(.system(size:))` :49 → the reading font helper. Replaces Noor's `SurahHeaderView`. |
| `M:Core/Components/SurahNameGlyph.swift` | adapt | `Q/Library/SurahNameGlyph.swift` | M4 | QUL `surah-name-v2` ligatures from `font_ligature`; text fallback. Replaces Noor's `Core/Theming/SurahNameGlyph.swift` (unlicensed table, deleted M3). |
| `M:Core/Diagnostics/DebugLaunchOptions.swift` | drop / see Q2 | (maybe `Q/Debug/QuranLaunchOptions.swift`, DEBUG only) | M5 | The 34 `-debug*` hooks drive the Mushaf UI tests. Whether a slim subset comes back is open question Q2. |
| `M:Core/Diagnostics/DebugSearch.swift` | drop | — | — | Timing print. |
| `M:Core/Diagnostics/DebugSpreadRenderer.swift` | drop | — | — | PNG export helper. |
| `M:Core/Diagnostics/DebugUserData.swift` | drop | — | — | Seeds khatmah/backup; see Q2 for the seeding subset. |
| `M:Core/Diagnostics/DebugWidgetRenderer.swift` | drop | — | — | Widget previews (`#Preview`) replace it, as Noor's widgets do. |
| `M:Core/Diagnostics/DebugWindowOptions.swift` | drop | — | — | Window snapshot harness. |
| `M:Core/Diagnostics/FrameMonitor.swift` | drop | — | — | Instruments replaces it. |
| `M:Core/Diagnostics/PerformanceProbe.swift` | adapt (DEBUG) | `Q/Debug/PerformanceProbe.swift` | M4 | Needed for M4's "memory flat paging 1→604" and M8's size/perf proof; drives `measure-performance.sh`. |
| `M:Core/Fonts/FontRegistrar.swift` | replace | `Core/Theming/FontRegistrar.swift` | M2 | Noor's registrar plus the V2 exclusion (T1). |
| `M:Core/Fonts/PlatformFont.swift` | port | `Q/Data/Fonts/TextMeasurer.swift` | M4 | `nonisolated` measurement, `#if canImport` glue. |
| `M:Core/Fonts/QuranFont.swift` | adapt | `Sh/Theming/Domain/ReaderFont.swift` + `Sh/Theming/UI/QuranTypography.swift` | M4 | One catalogue of Quran faces (Hafs, Amiri, QUL header/name/common). `.system` fallbacks :57, :63 go through `AppFont`. |
| `M:Core/Formatting/NumeralSystem.swift` | replace | `LocalizationManager` / `NumberSystem` | M4 | D4. 12+ `numerals.format` call sites move with their files. |
| `M:Core/Formatting/TafsirMarkup.swift` | adapt | `Q/Domain/Markup/TafsirDocument.swift` (parse) + `Q/Tafsir/TafsirStyling.swift` (fonts) | M5 | Keep the `nonisolated(unsafe)` regex (:111) with its invariant documented. `.system(size:)` :83 and `"\(n)."` :176 fixed. |
| `M:Core/Formatting/TranslationMarkup.swift` | adapt | `Q/Domain/Markup/TranslationDocument.swift` + styling in `Q/Translation/` | M5 | Same split; `footnote://` stays in-app. |
| `M:Core/Platform/AppMenu.swift` | adapt | `App/QuickActions/AppSceneDelegate.swift` (`AppDelegate`) | M7 | Merge "remove UIKit's Find menu" into Noor's existing iOS `AppDelegate`; there must be one delegate. |
| `M:Core/Platform/DeviceKind.swift` | port | `Core/Platform/DeviceKind.swift` | M4 | Used by the pager's tap handling and landscape rules. |
| `M:Core/Platform/Haptics.swift` | replace | `.sensoryFeedback` | M5 | Tasbih and the adhkar already use `.sensoryFeedback`; one mechanism. |
| `M:Core/Platform/KeyCommands.swift` | adapt | `Q/Platform/QuranCommands.swift` | M7 | Single command table kept; titles → `L10nKey` (:24–36, :107); menu visible only while the Quran section is focused (T11). |
| `M:Core/Platform/MacInputMonitor.swift` | port | `Q/Platform/MacInputMonitor.swift` | M7 | macOS glue; `WheelAccumulator` tests come with it. |
| `M:Core/Platform/MacWindowRecovery.swift` | drop | — | — | Multi-window (D3). |
| `M:Core/Platform/PagingKeyResponder.swift` | port | `Q/Platform/PagingKeyResponder.swift` | M7 | iPad hardware keys. |
| `M:Core/Platform/Pasteboard.swift` | port | `Core/Platform/Pasteboard.swift` | M5 | Generic; no Noor equivalent exists. |
| `M:Core/Platform/SheetSizing.swift` | port | `Q/Platform/SheetSizing.swift` | M5 | macOS sheet frames. |
| `M:Core/Platform/ToolbarSearchField.swift` | port | `Q/Platform/ToolbarSearchField.swift` | M5 | macOS `NSSearchField`. |
| `M:Core/Platform/WindowOpener.swift` | drop | — | — | "Open in New Window" (D3). |
| `M:Core/Theme/ReaderTheme.swift` | adapt | `Sh/Theming/Domain/ReaderTheme.swift` + `Sh/Theming/UI/ReadingStyle.swift` + colour sets in `Sh/Resources/SharedAssets.xcassets/Reader/` | M4 | T9. Every literal (:24–69, :89–90, :109) becomes a named light/dark colour set read through `AppColor`. Replaces Noor's `ReaderPaper`. |

### 1.3 `Mushaf/Domain` (9 files)

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `M:Domain/QuranModels.swift` | adapt | `Q/Domain/QuranModels.swift`; `AyahID` → `Sh/Quran/Domain/VerseReference.swift` | M3 | T7. `AyahID.init?(parsing:)` (Arabic-Indic digits, `:` `/` space) merges into `VerseReference`. `Surah`, `Ayah`, `MushafPage`, `MushafLine`, `Segment`, `RevelationPlace` move as is. |
| `M:Domain/QuranCorpus.swift` | port | `Q/Domain/QuranCorpus.swift` | M3 | Navigation indices. |
| `M:Domain/QuranMetadata.swift` | port | `Q/Domain/QuranMetadata.swift` | M3 | |
| `M:Domain/ContentPack.swift` | adapt | `Q/Domain/ContentPack.swift` | M3 | Mushaf's `AppLanguage` (:148–154, reads `Bundle.main`) → Noor's `AppLanguage`. `NumeralSystem` (:184–190) → `LocalizationManager`. |
| `M:Domain/Khatmah.swift` | drop | — | — | D3. |
| `M:Domain/MarginMarker.swift` | port | `Q/Domain/MarginMarker.swift` | M3 | |
| `M:Domain/MushafStyle.swift` | port | `Q/Domain/MushafStyle.swift` | M3 | One style (`madaniV2`); the font folder name is the contract with T1/T14. |
| `M:Domain/Search.swift` | adapt | `Q/Domain/QuranSearch.swift` | M3 | Folding/expressions from `AT/` and `Core/Search` (T3); `LocalizedStringResource` titles (:15–21) → `L10nKey`. `SearchHighlight` kept pending Q4. |
| `M:Domain/UserData.swift` | adapt | `Q/Domain/QuranUserData.swift` | M6 | Bookmarks, notes, highlights; khatmah (:56–113, :162–169) and backup (:169–173, snapshot) removed. `storageKey` "s:a" == `RecentActivity`'s format, good. |

### 1.4 `Mushaf/Data` (19 files)

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `M:Data/QuranRepository.swift` | adapt | `Q/Domain/QuranRepositoring.swift` | M3 | Protocol renamed to Noor's `-ing` convention; every method stays `@concurrent`. |
| `M:Data/Quran/SQLiteQuranRepository.swift` | adapt | `Q/Data/QuranRepository.swift` | M3 | Reads through `CorpusDatabaseProviding`; the raw-`sqlite3` fast path keeps working via GRDB's `db.sqliteConnection`. Prefers `quran-mushaf` when bundled, else `quran` (T4). |
| `M:Data/Quran/QuranDatabase.swift` | replace | `Core/Persistence/Corpus/CorpusDatabase` | M3 | Its own lazy queue → the shared provider. |
| `M:Data/Content/ContentPackStore.swift` | adapt | `Q/Data/Packs/ContentPackStore.swift` | M3 | Discovers packs by their own `pack` table, not a bundled `manifest.json` (T15). |
| `M:Data/Content/TranslationRepository.swift` | adapt | `Q/Data/Packs/TranslationRepository.swift` | M3 | `PackDatabase` actor kept; opens through a `CorpusDatabase` per pack; `ATTACH … AS quran` checked against GRDB's read-only config in M3. |
| `M:Data/Content/TafsirRepository.swift` | adapt | `Q/Data/Packs/TafsirRepository.swift` | M3 | Must preserve Noor's "`nil` is an answer" contract for Jalalayn (T16). |
| `M:Data/Content/SurahInfoRepository.swift` | adapt | `Q/Data/Packs/SurahInfoRepository.swift` | M3 | QUL-only data; absent in the Tanzil build → screen hides the info row. |
| `M:Data/Search/SQLiteSearchRepository.swift` | adapt | `Q/Data/QuranSearchRepository.swift` | M3 | Stop opening a second queue on `quran.sqlite`; share the corpus reader. |
| `M:Data/Search/RecentSearchStore.swift` | replace | `SettingsKey.quranRecentSearches` (JSON string) | M5 | `SettingsStore` holds string/bool/double, so the list of eight is one JSON string. |
| `M:Data/ReaderStateStore.swift` | replace | `SettingsKey` per field (M4) + `ReadingPosition` (M6) | M4/M6 | The `"readerState"` blob dies. |
| `M:Data/SharedReaderState.swift` | drop | — | — | Cross-window state (D3). Its per-style corpus `Task` cache moves into the reader view model. |
| `M:Data/Assets/FontPackStore.swift` | port | `Q/Data/Fonts/FontPackStore.swift` | M4 | Actor + `OSAllocatedUnfairLock` kept exactly (T13). Window ±3, release beyond 20. Injected, not global. |
| `M:Data/AyahOfTheDayList.swift` | adapt | `Q/Data/AyahOfTheDayList.swift` | M7 | `"\(s):\(a)-\(b)"` (:15) is a storage key, not UI; rename to `VerseReference`. |
| `M:Data/User/UserDataSchema.swift` | adapt | `Q/Data/UserData/QuranUserDataRecords.swift` | M6 | `@Model` `AyahBookmarkRecord`, `AyahNoteRecord`, `AyahHighlightRecord`, `QuranReadingPositionRecord`, listed in `PersistenceController.schema`. No `VersionedSchema` (Noor has none). |
| `M:Data/User/SwiftDataUserDataRepository.swift` | adapt | `Q/Data/UserData/QuranUserDataRepository.swift` (`@ModelActor`) + `Q/QuranUserDataStore.swift` | M6 | The biggest shape change; see concept map ("user data"). Own container (:105–118) removed. |
| `M:Data/User/BackupFile.swift` | drop | — | — | D3. |
| `M:Data/User/BackupService.swift` | drop | — | — | D3. |
| `M:Data/User/KhatmahReminders.swift` | drop | — | — | D3, and T2's 64-notification budget stays with prayer reminders. |
| `M:Data/User/LegacyBookmarkMigration.swift` | drop | — | — | D2: no users to migrate. |

### 1.5 `Mushaf/Features/Reader` (32 files)

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `ReaderRootView.swift` | adapt | `Q/Reader/QuranReaderView.swift` | M5 | Layout logic kept (pager / separated / tabletop / inspector); DEBUG block (:182–226) gone; immersive mode also hides the tab bar (T11); size rules read the detail column, not the window. |
| `ReaderModel.swift` | adapt | `Q/Reader/QuranReaderViewModel.swift` + `QuranCoordinator` | M5 | Navigation (`go(to:)` :141–172) moves to the coordinator; khatmah `showPage` (:129–138) dropped. |
| `ReaderCommandTarget.swift` | adapt | `Q/Platform/QuranCommandTarget.swift` | M7 | |
| `ReaderToolbar.swift` | adapt | `Q/Reader/QuranReaderToolbar.swift` | M5 | Khatmah button (:80–84) gone. |
| `Settings/ReaderSettings.swift` | adapt | `Q/Settings/QuranReaderSettings.swift` | M4 | One Codable blob → one `SettingsKey` per field (see concept map). Replaces Noor's `ReaderSettings`. |
| `Settings/ReaderSettingsView.swift` | adapt | `Q/Settings/QuranReaderSettingsSheet.swift` | M5 | Replaces Noor's `ReaderSettingsSheet`; keeps Noor's keep-awake row and adds Amiri as a separated-mode font (D4). Backup row (:71–78, :160) and numerals picker (:128–136) dropped. |
| `Settings/SettingsWindow.swift` | drop | — | — | Mac shows the same sheet/inspector in the Quran section; Noor's Settings scene stays app-wide. |
| `GoTo/GoToTarget.swift` | port | `Q/Domain/GoToTarget.swift` | M3 | Typed-keyword sets (:40–43) are matched input, not display text: stays literal, documented. |
| `AyahActions/AyahActions.swift` | adapt | `Q/AyahActions/AyahActions.swift` | M5 (M6 wiring) | `numerals.format` :16. |
| `AyahActions/AyahContextMenu.swift` | adapt | `Q/AyahActions/AyahContextMenu.swift` | M5 | Highlight swatches :117–120 → colour sets. |
| `AyahPanel/AyahPanel.swift` | adapt | `Q/AyahPanel/AyahPanel.swift` | M5 | Keep the 4-line cap; move `TextMeasurer.lineHeight` (:102–104) out of `body`. `.textSelection(.enabled)` :145 must be checked against the adhkar finding. |
| `AyahPanel/PanelActionButtonStyle.swift` | adapt | `Q/AyahPanel/PanelActionButtonStyle.swift` | M5 | Palette → reading tokens. |
| `Separated/SeparatedReaderView.swift` | adapt | `Q/Separated/SeparatedReaderView.swift` | M5 | DEBUG probe (:102–106, :130–148) gone. Reuse the Noor lessons: flattened `LazyVStack` children, and the position write parked on a `Task` the list awaits. |
| `Separated/SurahListView.swift` | drop | — | M5 | Superseded by the Library's surah tab, which is the tab root. |
| `Tafsir/TafsirChoice.swift` | port | `Q/Domain/TafsirChoice.swift` | M5 | Packs give several editions now, so the picker earns its place. |
| `Tafsir/TafsirReaderView.swift` | adapt | `Q/Tafsir/TafsirReaderView.swift` | M5 | Replaces Noor's `TafsirPanel`. |
| `Tafsir/TafsirSection.swift` | adapt | `Q/Tafsir/TafsirSection.swift` | M5 | Keep the `Task.detached` HTML parse (:76), with a comment on why it is detached. Adds Noor's `.silent` state (T16). |
| `Tafsir/TafsirTextView.swift` | adapt | `Q/Tafsir/TafsirTextView.swift` | M5 | `.system(size:)` :42 → reading font. |
| `Translation/TranslationTextView.swift` | adapt | `Q/Translation/TranslationTextView.swift` | M5 | |
| `Mushaf/JustifiedLine.swift` | port | `Q/Mushaf/JustifiedLine.swift` | M4 | `Font.custom(_:fixedSize:)` :106 is the renderer's own sizing (page fit), a documented exception like `AyahTextBuilder` was. |
| `Mushaf/MarginMarkerLabel.swift` | adapt | `Q/Mushaf/MarginMarkerLabel.swift` | M4 | |
| `Mushaf/MushafFold.swift` | adapt | `Core/Layout/FoldGeometry.swift` | M4 (T12 settled M7) | The pager needs it in M4. iOS 27.1 `reservedRegions` path stays gated; DEBUG overrides go (:78–102). |
| `Mushaf/MushafPagerView.swift` | adapt | `Q/Mushaf/MushafPagerView.swift` | M4 | |
| `Mushaf/MushafPageView.swift` | adapt | `Q/Mushaf/MushafPageView.swift` | M4 | |
| `Mushaf/MushafPageContent.swift` | adapt | `Q/Mushaf/MushafPageContent.swift` | M4 | |
| `Mushaf/MushafPageMetrics.swift` | port | `Q/Mushaf/MushafPageMetrics.swift` | M4 | `PageMeasurement.init` must never run on main (doc'd). |
| `Mushaf/MushafPageUnit.swift` | port | `Q/Mushaf/MushafPageUnit.swift` | M4 | Fed the detail column's size (T11). |
| `Mushaf/MushafPageAccessibility.swift` | adapt | `Q/Mushaf/MushafPageAccessibility.swift` | M4 | `AnyView` :200–204 → `@ViewBuilder`. |
| `Mushaf/MushafTapZones.swift` | port | `Q/Mushaf/MushafTapZones.swift` | M4 | |
| `Mushaf/PageRenderer.swift` | port | `Q/Mushaf/PageRenderer.swift` | M4 | Glyph vs Unicode renderer; the Unicode path is the whole Mushaf mode in a Tanzil build (if Mushaf mode is offered there at all; T4 says it is hidden). |
| `Mushaf/PageMetricsCache.swift` | adapt | `Q/Mushaf/PageMetricsCache.swift` | M4 | `static let shared` :13 → one instance owned by `AppContainer`. Actor + `Task.detached` kept. |
| `Mushaf/TabletopBottomView.swift` | adapt | `Q/Mushaf/TabletopBottomView.swift` | M7 | iPhone Duo tabletop is in scope (D3). |

### 1.6 Library, Search, Bookmarks, Content, About (9 files) and the dropped folders

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `Library/LibraryView.swift` | adapt | `Q/Library/QuranLibraryView.swift` (+ rows split out) | M5 | **The Quran tab root**: go-to field + Surah / Juz / Hizb / Page. Continue reading joins it in M6. 386 lines → split under the 60-line body rule. |
| `Library/SurahInfoView.swift` | adapt | `Q/Library/SurahInfoSheet.swift` | M5 | Keep the detached HTML parse; `.textSelection` :26 checked on device. |
| `Search/SearchView.swift` | adapt | `Q/Search/QuranSearchView.swift` | M5 | `.task(id:)` + `Task.sleep` debounce is already Noor's mechanism. Scopes: Quran / translations / surah names. Highlighting pending Q4. |
| `Bookmarks/BookmarksView.swift` | adapt | `Q/Bookmarks/QuranBookmarksView.swift` | M6 | Relative date via `LocalizationManager`. |
| `Bookmarks/BookmarkList.swift` | port | `Q/Domain/BookmarkList.swift` | M6 | Pure. |
| `Bookmarks/NoteEditorView.swift` | adapt | `Q/Bookmarks/NoteEditorView.swift` | M6 | |
| `Content/ContentPackSelection.swift` | port | `Q/Domain/ContentPackSelection.swift` | M5 | Drop the unused `import SwiftUI`. Ordered ids → one `SettingsKey` string. |
| `Content/ContentPacksView.swift` | adapt | `Q/Settings/ContentPacksView.swift` | M5 | |
| `About/AboutView.swift` | adapt | Noor's Settings → Sources (`Features/Settings/Domain/AttributionSource.swift` + its screen) | M5 | One attribution screen for the app. Licence text verbatim; the "reading plan" sentence (:30) goes with khatmah. |
| `Backup/BackupDocument.swift`, `Backup/BackupView.swift` | drop | — | — | D3. |
| `Khatmah/KhatmahView.swift` | drop | — | — | D3. The khatmah/backup hooks spread across 15 other files (listed by scout d) disappear as each file is ported. |

### 1.7 Widget, `Shared`, package, builder, scripts

| Mushaf file | Action | Destination | M | Notes |
|---|---|---|---|---|
| `MushafWidget/MushafWidgets.swift` | adapt | `NoorWidgets/Views/ContinueReadingWidget.swift`, `AyahOfTheDayWidget.swift` (+ providers in `NoorWidgets/Utilities/`) | M7 | Kinds `ContinueReadingWidget` / `AyahOfTheDayWidget`, which must not change once shipped. No clash with Noor's four kinds. Same completion-handler `TimelineProvider` shape Noor's providers already use. |
| `MushafWidget/Localizable.xcstrings` (10 keys) | replace | `L10nKey` + `Sh/Localizable.xcstrings` | M7 | |
| `MushafWidget/PrivacyInfo.xcprivacy` | adapt | merge into NoorWidgets (it has none today) | M7 | Declares the `UserDefaults` reason the App Group needs. |
| `Shared/WidgetSnapshot.swift` | adapt | `Sh/Widgets/Domain/QuranWidgetSnapshot.swift`, `Sh/Widgets/Domain/DailyAyahRule.swift` | M7 | `DailyAyahRule` ports as is. `WidgetLink` → `DeepLink`. `WidgetStore` → `SharedDefaults` + `SettingsStore`. Own `Locale` digits (:61) → widget's `\.locale` numbering system, as the prayer widgets do. |
| `Shared/WidgetViews.swift` | adapt | `NoorWidgets/Views/QuranWidgetViews.swift` | M7 | RGB `WidgetPalette` (:229–232) → reading colour sets; step sizes (:146–153) stay as the fit-to-widget ladder, with the reason documented. |
| `Packages/QuranText/Package.swift` | adapt | `AT/Package.swift` | M2 | Module `ArabicText`; platforms iOS 17 / **macOS 15**; Swift 6 language mode kept. |
| `…/ArabicSearchNormalizer.swift` | adapt | `AT/Sources/ArabicText/ArabicNormalizer.swift` | M2 | The single normalizer (T3). Reconciliation rules are in §4. |
| `…/ArabicPrefixStemmer.swift` | port | `AT/Sources/ArabicText/ArabicPrefixStemmer.swift` | M2 | Quran-only use in v1. |
| `…/LineSegmentation.swift` | port | `AT/Sources/ArabicText/LineSegmentation.swift` | M2 | Used by the builder and the page layout. |
| `…/Tests/QuranTextTests.swift` | adapt | `AT/Tests/ArabicTextTests/` | M2 | Plus the reconciled cases and the Python parity word list. |
| `Scripts/BuildQuranData/Package.swift` | adapt | `QB/Package.swift` | M2 | macOS 15; depends on `../../Packages/ArabicText`. |
| `Sources/BuildQuranData/Config.swift` | adapt | `QB/Sources/QuranBuilder/Config.swift` | M2 | Gains `profile: tanzil | qul`. |
| `Sources/BuildQuranData/main.swift` | adapt | `QB/Sources/QuranBuilder/main.swift` | M2 | `--profile`; Release guard hook. |
| `Sources/BuildQuranData/Inputs.swift` | adapt | `QB/Sources/QuranBuilder/Inputs/QULInputs.swift` + new `TanzilInputs.swift` | M2 | Tanzil loader ports `build_quran_db.py`'s download + digest checks. |
| `Sources/BuildQuranData/QuranSQLiteBuilder.swift` | adapt | `QB/Sources/QuranBuilder/QuranSQLiteBuilder.swift` | M2 | **One schema** for both profiles (T4); `tanzil` leaves `word.glyph_v2`, `mushaf_*`, `marker`, `font_ligature` empty and says so in `meta.capabilities`. |
| `Sources/BuildQuranData/Packs.swift` | adapt | `QB/Sources/QuranBuilder/Packs.swift` | M2 | Jalalayn becomes a pack built from the `spa5k` mirror (ported from `build_tafsir_db.py`). |
| `Sources/BuildQuranData/Fonts.swift` | port | `QB/Sources/QuranBuilder/Fonts.swift` | M2 | `qul` profile only. |
| `Sources/BuildQuranData/Curated.swift` | port | `QB/Sources/QuranBuilder/Curated.swift` | M2 | |
| `Sources/QuranDataModel/` `CuratedAyahList`, `SQLite`, `SizeReport`, `SourceManifest`, `StaticTables`, `TafsirHTML`, `TranslationMarkup` (7 files) | port | `QB/Sources/QuranDataModel/` | M2 | `StaticTables` stays for the `qul` profile; `tanzil` reads `quran-data.xml`. `SourceManifest` gains a Tanzil digest list (the two pins from `build_quran_db.py`, the one from `build_tafsir_db.py`). |
| `Tests/QuranDataIntegrityTests/` `CuratedListTests`, `Expectations`, `PackTests`, `QuranSQLiteTests` (11 suites), `SurahInfoPackTests`, `TafsirPackTests` (6 files) | adapt | `QB/Tests/QuranDataIntegrityTests/` | M2 | Layout/glyph/font/QUL-pack suites run only when their inputs exist; a Tanzil suite is added (verse text byte-identical to Tanzil Uthmani, 226 silent Jalalayn verses). |
| `Scripts/BuildQuranData/README.md` | adapt | `QB/README.md` | M2 | Two profiles; findings kept. |
| `Scripts/golden-pages.sh` | adapt | `Tools/QuranBuilder/scripts/golden-pages.sh` | M4 | There is **no golden-image comparison** in Mushaf (scout f). M4 captures reference shots from the reference project and compares them by eye; see Q3. |
| `Scripts/measure-performance.sh` | adapt | `Tools/QuranBuilder/scripts/measure-performance.sh` | M4 | Reads `PerformanceProbe` lines. |
| `Scripts/metrics/line-collisions.swift`, `word-collisions.swift` | drop | — | — | Leading tuning, finished in Mushaf. |
| `QuranData/build.json` | adapt | `QB/profiles/qul.json` + `QB/profiles/tanzil.json` | M2 | Not copied in M0. |
| `QuranData/curated/ayah-of-the-day.txt` | port | `QB/data/ayah-of-the-day.txt` (committed; own work) | M2 | Still "draft, to be reviewed by Saad"; `WidgetTests` asserts the status. |
| `QuranData/SOURCES.md`, `fonts-v2.sha256` | port (done M0) | `QuranData/` | M0 | |

### 1.8 Resources, config, project

| Mushaf item | Action | Destination | M |
|---|---|---|---|
| `M:Localizable.xcstrings` (214 keys, all ar+en; ~15 khatmah/backup/window; 34 with format args) | replace | `L10nKey` cases + `Sh/Localizable.xcstrings`, ported with the files that use them | M4–M7 |
| `M:InfoPlist.xcstrings` | drop | — (only the backup UTType names) | — |
| `M:Assets.xcassets` (AccentColor, AppIcon) | drop | — | — |
| `M:Resources/quran.sqlite`, `Packs/*`, `Fonts/*`, `ayah-of-the-day.json` | rebuilt | `QB` outputs, see T4/T14/T15 | M2 |
| `M:PrivacyInfo.xcprivacy` | compare | Noor's app manifest (add any missing reason) | M8 |
| `Config/*.plist`, `*.entitlements` | replace | Noor's Info.plist / entitlements (`SharedDefaults` group); `.quranbackup` UTType dropped | — |
| Xcode "Check V2 page fonts" build phase | adapt | Release-only guard script (T4) added by `Tools/add_quran_data_phase.rb` | M2 |
| `docs/release/LICENSES.md`, `license-requests.md` | reference | `Res/Licenses` + Corpus README | M8 |

### 1.9 `MushafTests` (30 files) → `T/Quran/`

"Guard" = runs only when the full (QUL) data is bundled; skipped with a reason in a Tanzil build (`.enabled(if: QuranCapabilities.bundled.hasMushafPages)` style trait).

| Mushaf test | Action | M | Notes |
|---|---|---|---|
| `DomainTests.swift` | adapt | M3 | `AyahIDTests` → `VerseReferenceTests` (merge with Noor's existing ones); `CorpusTests` guarded; `ReaderStateDecodingTests` dropped (no blob). |
| `SQLiteQuranRepositoryTests.swift` | adapt | M3 | Layout cases guarded; `missingDatabaseFailsToLoad` ports. |
| `SearchTests.swift` | adapt | M3 | Folding/stem/FTS-syntax/too-short port; hit counts re-measured per profile; translation cases guarded; highlight cases per Q4. |
| `FTS5SpikeTests.swift` | port | M2 | Into `AT` or `T/Search`; keeps the "unnormalised Hafs is unsearchable" guard. |
| `TafsirRepositoryTests.swift` | adapt | M3 | QUL group counts guarded; Jalalayn silence cases (226) carried over from Noor's suite. |
| `TranslationRepositoryTests.swift` | adapt | M3 | Fixture tests port; bundled-manifest tests rewritten for T15 and guarded. |
| `ContentPackSelectionTests.swift` | adapt | M5 | One case guarded. |
| `MarginMarkerTests.swift` | adapt | M3 | 4 of 5 guarded. |
| `MushafStyleTests.swift` | adapt | M3 | 2 guarded. |
| `LocalizationDefaultsTests.swift` | adapt | M5 | Two numeral tests dropped (D4). |
| `FontPackStoreTests.swift` | adapt | M4 | Window maths ports; four QUL-only cases guarded. |
| `FontAndGlyphTests.swift` | adapt | M4 | Guarded (all six). |
| `PageMetricsCacheTests.swift` | adapt | M4 | 3 guarded. |
| `PageUnitTests.swift` | adapt | M4 | `landscapeTextIsReadable` guarded. |
| `RendererSelectionTests.swift` | adapt | M4 | 7 guarded; `LineTapTests` ports. |
| `ContrastTests.swift` | adapt | M4 | Against the new colour sets, all three themes, light and dark. |
| `AppRouterTests.swift` | adapt | M5 | → `QuranCoordinatorTests`. |
| `AyahPanelTests.swift` | adapt | M5 | 2 guarded. |
| `LibraryTests.swift` | adapt | M5 | juz/hizb/page cases and surah info guarded. |
| `TafsirChoiceTests.swift` | port | M5 | |
| `TafsirMarkupTests.swift` | adapt | M5 | `realEntries` guarded. |
| `TranslationMarkupTests.swift` | adapt | M5 | 3 guarded. |
| `BookmarkListTests.swift` | port | M6 | |
| `UserDataRepositoryTests.swift` | adapt | M6 | Khatmah lines and migration tests removed; re-shaped for `@ModelActor` + store. |
| `KeyCommandTests.swift` | adapt | M7 | Layout cases guarded. |
| `WidgetTests.swift` | adapt | M7 | `noor://` links; 2 guarded. |
| `WindowStateTests.swift` | split | M7 | `WheelAccumulatorTests` ports; the 6 window tests drop. |
| `BookmarkPersistenceTests.swift` | drop | — | Pre-SwiftData migration. |
| `BackupTests.swift`, `KhatmahTests.swift` | drop | — | D3. |

### 1.10 `MushafUITests` (19 files) → `UIT/Quran/`

| Mushaf UI test | Action | M |
|---|---|---|
| `ToolbarActions.swift` (helpers) | port first | M5 |
| `LaunchTests`, `BookmarkTests`, `TitleLayoutTests` | port | M5/M6 |
| `NavigationTests`, `SearchUITests`, `ImmersiveTests`, `AccessibilityTests`, `AccessibilityAuditTests` (minus khatmah screen), `SeparatedTranslationTests`, `TafsirPanelTests`, `StudyFeatureTests` | adapt; page numbers are layout facts, so guard on full data | M5/M6 |
| `KeyboardTests`, `FoldPanelTests`, `TabletopTests`, `WidgetLinkTests` (`noor://`) | adapt | M7 |
| `PhaseSixScreenshots` | keep the spread+inspector case only | M7 |
| `BackupRoundTripTests`, `KhatmahUITests` | drop | — |

All of them drive the app through `-debug*` launch arguments (34 hooks; `-debugMode` 38 uses, `-debugPage` 15). Without a harness they don't run, so **Q2 decides the UI-test strategy**.

---

## 2. ThawabForGod Quran files and touch points

### 2.1 `ThawabForGod/Features/Quran` (38 files): delete at M3, except as noted

| File | Action | M | Note |
|---|---|---|---|
| `Domain/Verse.swift` | split | M3 | `VerseReference` → `Sh/Quran/Domain/VerseReference.swift` (gains `init?(parsing:)`); `Verse`, `Sajda` deleted. |
| `Views/KeepScreenAwake.swift` | keep, move | M3 | → `Q/Reader/KeepScreenAwake.swift` (app target only; `UIApplication.shared`). |
| `ReaderSettings.swift` | replace | M3→M4 | Deleted M3; `QuranReaderSettings` (M4) keeps `readerFont` (Hafs/Amiri) and `readerKeepsScreenAwake`. |
| `Domain/Tafsir.swift`, `TafsirViewModel.swift` | replace | M3→M5 | The `.silent` vs `.unavailable` distinction survives inside the ported `TafsirSection` (T16). |
| All other 33 files (`GetQuranUseCase`, `GetTafsirUseCase`, `Juz`, `QuranBookmark`, `QuranProgressRepositoring`, `QuranProgressUseCase`, `QuranRepositoring`, `QuranSearch`, `ReadingPosition`, `Surah`; `Data/` `JuzRecord`, `QuranBookmarkRecord`, `QuranProgressRepository`, `QuranRepository`, `ReadingPositionRecord`, `SurahRecord`, `TafsirEditionRecord`, `TafsirRepository`, `VerseRecord`; `QuranCoordinator`, `QuranViewModel`; `Views/` `AyahTextBuilder`, `BookmarkRow`, `ContinueReadingCard` (re-made in M6), `JuzRow`, `QuranListView`, `ReaderSettingsSheet`, `ReaderView`, `SearchResultRow`, `SurahHeaderView`, `SurahRow`, `TafsirPanel`, `VerseRow`) | delete | M3 | T8: duplicate names (`Surah`, `RevelationPlace`, `SurahRecord`, `SurahRow`, `Sajda`, `QuranRepository`, `TafsirRepository`, `ReaderView`, `ReaderSettings`) make coexistence impossible. Lessons kept in the port: flattened lazy children, the position-write race, `.task(id:)` debounce. |

### 2.2 Touch points outside the feature

| File | Action | M | What changes |
|---|---|---|---|
| `App/AppContainer.swift` | adapt | M3–M7 | Quran wiring at :120–149, :198, :229–230, :339–380, :682–718 replaced step by step; M3 wires the new repositories and a placeholder; Home's Quran use cases pass `nil`. |
| `App/AppContainer+Routing.swift` | adapt | M3/M5 | `.quran` / `.quranVerse` → placeholder at M3, `QuranCoordinator.open(_:)` at M5. |
| `App/AppContainer+DeepLink.swift` | adapt | M7 | Exhaustive switch gains `.quranVerse` / `.quranPage` arms. |
| `App/AppRoute.swift` | keep | — | `.quranVerse(VerseReference)` unchanged (T7); `VerseReference` now resolves from `Shared/`. Possibly `.quranPage(Int)` in M5. |
| `App/AppSectionView.swift` | adapt | M3/M5 | :62–71 → placeholder (M3) → `QuranLibraryView` (M5). |
| `App/ThawabForGodApp.swift` | adapt | M2/M7 | `FontRegistrar` call (:31) unchanged; `.commands` gains `QuranCommands` (M7). |
| `App/QuickActions/AppSceneDelegate.swift` | adapt | M7 | iPad Find-menu removal merged in. |
| `App/QuickActions/AppQuickAction.swift` | keep | — | `.quran` action routes as before. |
| `Sh/DeepLink/Domain/DeepLink.swift` | adapt | M7 | `quranVerse(VerseReference)` → `noor://quran/verse/2/255`; `quranPage(Int)` → `noor://quran/page/42`. Additive; `noor://quran` unchanged. |
| `Core/Activity/Domain/RecentActivity.swift` | keep | M6 | Subject "s:v" unchanged; it is the same string Mushaf's `storageKey` writes. `progressTotal` stays verse count. |
| `Core/Persistence/Data/PersistenceController.swift` | adapt | M3/M6 | M3 removes `QuranBookmarkRecord`, `ReadingPositionRecord` (:22–23); M6 adds the four new records. |
| `Core/Persistence/Corpus/CorpusDatabase*.swift` | keep | M3 | Instantiated for `quran-mushaf` or `quran`, and per pack. Stale doc line ("Quran later") fixed in M8. |
| `Core/Search/Domain/ArabicSearchQuery.swift` | adapt | M2 | Delegates folding to `ArabicText`; API unchanged so hadith and adhkar search do not move. |
| `Core/Search/Data/FTS5Query.swift` | keep (extend) | M2/M3 | Gains the stem column for the Quran only. |
| `Core/Theming/FontRegistrar.swift` | adapt | M2 | T1 exclusion in the filter (:56–58). |
| `Core/Theming/SurahNameGlyph.swift` | delete | M3 | Unlicensed glyph table (D4). |
| `Sh/Theming/Domain/ReaderPaper.swift` | delete | M3 | → `ReaderTheme` (M4). |
| `Sh/Theming/Domain/ReaderTypography.swift` | delete | M3 | |
| `Sh/Theming/Domain/ReaderFont.swift` | adapt | M3/M4 | `AyahMarkerStyle` (:66–98) deleted M3; `kfgqpcHafs` + `amiriQuran` kept; QUL faces added M4. |
| `Sh/Theming/UI/QuranTypography.swift` | adapt | M3 | `AyahMarkerStyle` extension (:33–43) deleted. |
| `Sh/Theming/UI/ReadingStyle.swift`, `Theme.swift`, `AppColor.swift`, `AppFont.swift` | adapt | M3/M4 | `ReadingStyle` loses typography/marker; `Theme.reading(_:)` takes `ReaderTheme`; `AppColor.paper` → reader sets. |
| `Sh/Settings/Domain/SettingsStore.swift` | adapt | M3/M4 | Remove `readerPaper`, `readerTextSize`, `readerLineSpacing`, `readerShowsVerseNumbers`, `readerAyahMarkerStyle` (M3); add the `quran*` keys (M4). |
| `Sh/Localization/Domain/L10nKey.swift` + catalog | adapt | M3–M7 | 20 `quran*`, 5 `tafsir*`, 20 `reader*` keys: dead ones removed at M3 (`reader_paper_*`, verse numbers, line spacing, markers), the rest reused where wording fits. |
| `Features/Home/HomeViewModel.swift`, `Views/Sections/ContinueReadingSection.swift` | adapt | M3/M6 | `ContinueReading` holds `ReadingPosition`+`Surah` and the section draws Noor's `ContinueReadingCard`. M3: `nil` use cases (section hidden), struct re-typed. M6: the card moves to `Q/Library/ContinueReadingCard.swift` and Home reuses it. |
| `Features/Settings/Domain/AttributionSource.swift` | adapt | M5/M8 | Gains the pack and QUL font sources; AyahMarker/SurahNames rows removed. |
| `Res/Fonts/Quran/AyahMarker-1…12.ttf`, `SurahNames.ttf` | delete | M3 | D4; with them goes the last `TODO(license)` on fonts. |
| `Res/Fonts/Quran/KFGQPC-HafsUthmanic.ttf`, `AmiriQuran-Regular.ttf` | keep | — | KFGQPC is byte-identical to Mushaf's (and QUL's `UthmanicHafs_V22`). |
| `Res/Corpus/quran.sqlite` | regenerate | M2 | Built by `QB --profile tanzil` in the new schema. |
| `Res/Corpus/tafsir.sqlite` | replace | M2 | → `Res/Corpus/Packs/tafsir-ar-jalalayn.sqlite`. |
| `Res/Corpus/README.md` | rewrite (Quran/tafsir) | M2 | Already stale (`user_version` 2 vs 3, "nothing queries these indexes yet"). |
| `Tools/CorpusBuilder/build_quran_db.py`, `build_tafsir_db.py` | retire | M8 | After their Tanzil/mirror download and digest steps live in `QB`. `build_hadith_db.py` keeps its own `normalize()` + parity test (T3). |
| `NoorWidgets/` | extend | M7 | Two new kinds; four existing kinds untouched. |

### 2.3 ThawabForGod tests

| Test | Action | M |
|---|---|---|
| `T/Quran/QuranDoubles.swift` | **move `QuranStubError` first** (used by `T/Activity/ActivityRecorderTests.swift:117` and Home tests) to `T/TestSupport/StubError.swift`, then delete | M3 |
| `T/Quran/GetQuranUseCaseTests.swift` | keep `VerseReferenceTests` (:159–193) → `T/Quran/VerseReferenceTests.swift`; delete the rest | M3 |
| `T/Quran/QuranRepositoryTests.swift` | rewrite for the new schema; the "verse text byte-identical to Tanzil Uthmani" and Simple-Clean search assertions carry over | M3 |
| `T/Quran/TafsirRepositoryTests.swift`, `TafsirViewModelTests.swift` | rewrite: Jalalayn pack, 226 silent verses, `.silent` phase | M3/M5 |
| `T/Quran/ReaderSettingsTests.swift` | keep the face + keep-awake cases in `QuranReaderSettingsTests`; drop the rest | M4 |
| `T/Quran/QuranProgressRepositoryTests.swift`, `QuranViewModelTests.swift` | delete | M3 |
| `T/Typography/AyahTextBuilderTests.swift`, `SurahNameGlyphTests.swift`, `T/Theming/ReaderTypographyTests.swift` | delete | M3 |
| `T/Typography/FontRegistrarTests.swift` | adapt: new face list + "no `QCF2*` registered at launch" (T1) | M2 |
| `T/Typography/QuranFontCoverageTests.swift` | adapt to the new schema (Hafs still covers the corpus) | M3 |
| `T/Home/HomeViewModelTests.swift` (:612–800) | adapt: continue-reading cases re-pointed at M6; until then they assert the section is absent | M3/M6 |
| `T/DeepLink/DeepLinkTests.swift`, `DeepLinkRoutingTests.swift` | extend: the hand-written `all` list (:24–36) gains the two cases | M7 |
| `T/Activity/*`, `T/Search/*`, `T/Theming/AppBreakpointDuoTests.swift` | keep | — |
| `UIT/ScreenshotTourTests.swift` | its header says "TEMPORARY… Not to be committed", yet it is committed and drives the old Quran screens: see Q6 | M3 |

---

## 3. Concept map (Mushaf → ThawabForGod)

| Mushaf | ThawabForGod | Notes |
|---|---|---|
| `AyahID` | `VerseReference` (moved to `Sh/Quran/Domain`) | T7. Moving it to `Shared` is new: `DeepLink` and the widgets need it, and `Shared/` cannot see `Features/`. |
| `AyahID.storageKey` "s:a" | `RecentActivity` subject "s:v" | Same string; old activity rows resolve. |
| `ReaderTheme` / `ReaderPalette` / `HighlightMarks` | `ReaderTheme` (Domain) → `ReadingPalette` via `Theme.reading(_:)`; colours as `Reader/` sets in `SharedAssets.xcassets`, read only by `AppColor` | T9. Papers are fixed (same value light and dark), as Noor's were; "follow system" swaps Paper↔Dark. |
| `NumeralSystem` | `LocalizationManager` / `NumberSystem` | D4. |
| `AppRouter` (sheets, panel) | `QuranCoordinator` (typed `QuranRoute` path + sheet/panel state) | Path lives outside the view tree, as every other section's does. |
| `AppEnvironment` | `AppContainer` | Constructor injection; `PageMetricsCache` and `FontPackStore` become container-owned instances. |
| `ReaderModel` | `QuranReaderViewModel` (`@Observable @MainActor`) | |
| `ReaderSettings` (Codable blob) / `ReaderStateStore` / `UserDefaults` | `QuranReaderSettings` over `SettingsStore`, one key each: `quranDisplayMode`, `quranReaderTheme`, `quranFollowsSystemAppearance`, `readerTextSize` (reused: separated size 18…48, default 28), `readerFont` (Hafs/Amiri, separated only), `readerKeepsScreenAwake`, `quranShowsMarginMarkers`, `quranShowsTranslationInSeparated`, `quranEnabledTranslations`, `quranEnabledTafsirs`, `quranDefaultTafsir`, `quranPhoneLandscape`, `quranFlatOpen`, `quranRecentSearches` | Only keys the reader touched are written (Noor's settings rule). Lists are JSON strings. `mushafStyle` and `numerals` are not keys. |
| `@SceneStorage("reader.place")` / `ReaderLocation` | `ReadingPosition` (`@Model`, single row) + `RecentActivity` | M6. |
| `UserDataSchemaV1` + `SwiftDataUserDataRepository` (`@MainActor`, own container, synchronous reads in `body`) | Four `@Model` records in `PersistenceController.schema`; `QuranUserDataRepository` `@ModelActor`; **`QuranUserDataStore`** `@Observable @MainActor` cache loaded from it and updated optimistically | Mushaf's views read bookmarks/highlights synchronously per page; the store keeps that possible without putting SwiftData on the main actor. Uniqueness on `VerseReference` in the repository (iOS 17). |
| `QuranDatabase` / `PackDatabase` / own queues | `CorpusDatabase` via `CorpusDatabaseProviding` | |
| `QuranRepository` (protocol) | `QuranRepositoring` | Noor's naming. |
| `QuranText` package | `Packages/ArabicText` | T3. |
| `BuildQuranData` | `Tools/QuranBuilder` | T4. |
| `mushaf://page/n`, `mushaf://ayah/s/a` (`WidgetLink`) | `DeepLink.quranPage`, `DeepLink.quranVerse` → `noor://quran/page/n`, `noor://quran/verse/s/a` | T5. |
| `WidgetStore` (App Group `UserDefaults`, `MushafAppGroup` Info.plist key) | `SharedDefaults` + `SettingsStore`; Hafs copied to the group container | T5. |
| Mushaf strings (`Text("…", comment:)`, `LocalizedStringResource`) | `L10nKey` + `l10n.string(_:)` | T10. |
| Mushaf `FontRegistrar` / `QuranFont` | Noor `FontRegistrar` (launch faces) + `FontPackStore` (page faces) + `ReaderFont` | T1. |
| `MushafFold` | `Core/Layout/FoldGeometry` | T12, restated in §4. |
| `Haptics` | `.sensoryFeedback` | |
| `AboutView` | Settings → Sources (`AttributionSource`) | One credits screen. |
| `DebugLaunchOptions` | Q2 | |
| `SettingsWindow` (Mac) | Reader settings sheet/inspector inside the Quran section | |
| Mushaf `AppLanguage` | Noor `AppLanguage.current(in:)` | Two types with one name would collide. |
| `ReaderCommands` + `focusedSceneValue(\.readerCommandTarget)` | `QuranCommands`, published by the Quran section only | T11. |

---

## 4. Traps T1–T13, with the exact files, plus four new ones

| # | Files | What the scouts found that changes the fix |
|---|---|---|
| **T1** | `Core/Theming/FontRegistrar.swift:46–59` (recursive walk of `Bundle.main.resourceURL`, keeps `.ttf/.otf`); `T/Typography/FontRegistrarTests.swift`; `Q/Data/Fonts/FontPackStore.swift`; `Q/Domain/MushafStyle.swift` (folder name `madaniV2`) | The filter skips any URL with a path component `madaniV2`. Name and test the folder constant once, in `MushafStyle`. See T14 for where the folder lives. |
| **T2** | — | Removed with khatmah. `KhatmahReminders.swift` is not ported. |
| **T3** | `AT/Sources/ArabicText/ArabicNormalizer.swift`; `Core/Search/Domain/ArabicSearchQuery.swift:48–89`; `QB/.../QuranSQLiteBuilder.swift`; `Tools/CorpusBuilder/build_hadith_db.py` `normalize()`; **`.gitignore` line `Packages/`** | **The repo's `.gitignore` ignores `Packages/`**, so `Packages/ArabicText` would never be committed. M2 must narrow that rule. The two normalizers differ in real ways (scout e): Mushaf drops a fixed range list (U+064B–065F, U+0670, U+0640, U+06D6–06ED, *including* the small waw/yeh U+06E5/U+06E6), keeps punctuation inside tokens, and emits one string; Noor (and Python) drop by combining class and split on every non-letter/digit. Reconciled rule: **Noor's tokenisation** (it is what makes FTS syntax un-injectable) **+ Mushaf's U+06D6–06ED removal** (quranic signs are not word breaks: `قل۞هو`). Python's hadith normalizer is already the combining-class rule; the parity test pins both. |
| **T4** | `QB/profiles/*.json`; `Res/Corpus/quran.sqlite` (committed) vs `quran-mushaf.sqlite` (ignored); `Q/Data/QuranRepository.swift`; `Res/Corpus/Packs/`; `Tools/add_quran_data_phase.rb` | Mushaf's schema (`surah`, `ayah`, `word`, `mushaf_line`, `mushaf_page`, `marker`, `ayah_fts(text_norm, text_stem)`, `meta`, `font_ligature`) differs from Noor's (`verse`, `verse_fts`, `surah_fts`…), so every Noor Quran repository, test and the README section are rewritten at M2–M3. `tanzil` fills `ayah` from Tanzil Uthmani + Simple Clean (Noor's search fix survives), `juz/hizb/rub` from `quran-data.xml`, pages from Tanzil's page table. **Checked:** Tanzil's pages and the V2 layout agree on 6,180 of 6,236 verses; 56 start one page apart (43 later, 13 earlier in V2; e.g. 5:77 is p.121 in Tanzil and p.120 in V2, most of Ar-Rahman 55:17–68 shifts). A fallback page number is therefore not a V2 page number: Q5. |
| **T5** | `Sh/DeepLink/Domain/DeepLink.swift`; `App/AppContainer+DeepLink.swift`; `Sh/Widgets/Domain/QuranWidgetSnapshot.swift`; `NoorWidgets/` | `VerseReference` must move to `Shared/` first (M3), or `DeepLink.quranVerse` cannot compile in the widget target. The Hafs copy into the group container is app-side code Mushaf kept outside `Shared/`; it goes in `QuranWidgetPublisher`. |
| **T6** | `QB/Sources/QuranDataModel/SizeReport.swift`; budget in `QB/profiles/qul.json` (200 MB compressed, 400 MB installed) | Port as is; the M8 report also covers the existing corpora (hadith is 24 MB). |
| **T7** | `Sh/Quran/Domain/VerseReference.swift`; `App/AppRoute.swift:35`; `Core/Activity/Domain/RecentActivity.swift:102–127` | Confirmed safe: `RecentActivity` writes "surah:verse", which is Mushaf's `storageKey` format. |
| **T8** | §2.1; `T/Quran/*`; `Core/Theming/SurahNameGlyph.swift` | Collateral the plan didn't list: **Home's continue-reading** (`HomeViewModel.ContinueReading`, `ContinueReadingSection` → Noor's `ContinueReadingCard`) and **`QuranStubError`** used by Activity and Home tests. Both are handled in M3 as above. The placeholder covers the Quran tab *and* Home's section (hidden while `nil`). |
| **T9** | `Sh/Resources/SharedAssets.xcassets/Reader/`; `Sh/Theming/UI/AppColor.swift`, `Theme.swift`; `Q/AyahActions/AyahContextMenu.swift:117–120`; `NoorWidgets/Views/QuranWidgetViews.swift` | Three palettes × (background, text, secondary, ornament, selection, success, warning) + four highlight shades ×3 themes, plus the widget palette. Alpha *masks* (`AyahPanel` :122–127, `TafsirSection` :106–111) use `.black` only for its alpha: one documented `FadeMask` helper, the single exception. |
| **T10** | All ported views; `Sh/Localization/Domain/L10nKey.swift`; `Sh/Localizable.xcstrings` | 214 Mushaf + 10 widget keys; ~15 die with khatmah/backup/windows; 34 carry format arguments, and every number among them goes through `l10n.string(Int)`. ~200 new or reused keys. |
| **T11** | `Q/Reader/QuranReaderView.swift` (Mushaf `ReaderRootView` :150–153, :234, :287–293, :315–332); `Q/Mushaf/MushafPageUnit.swift`; `Q/Platform/QuranCommands.swift`; `App/ThawabForGodApp.swift:47–55, :83–113` (`SectionCommands`) | `.toolbar(.hidden, for: .tabBar)` joins the existing navigation-bar/status-bar hiding. Mushaf's `usesInspector` is "Mac always", which inside Noor's split view means a third column on the detail side: keep it, but measure against the detail column. `⌘G` (library) and `⌘T` don't clash with ⌘1–4. |
| **T12** | `Core/Layout/FoldGeometry.swift`; `Features/Adhkar/Views/AdhkarReadingView.swift:130–160` | **The premise doesn't hold**: the adhkar reader has no fold *measurement*. It hands the fold to the system's `ArrangementView` (iOS 27.1, regular width). Only Mushaf measures (`reservedRegions`). There is nothing to merge; Q1 asks how you want that recorded. |
| **T13** | Every ported `nonisolated` / `actor` / `@concurrent` / `Task.detached` / `nonisolated(unsafe)` (lists in the scout notes; key ones: `FontPackStore`, `PageMetricsCache`, `QuranRepositoring`'s `@concurrent` methods, both markup regexes, `TafsirSection` and `SurahInfoView` detached parses) | Mushaf already uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (checked in its project), so the only difference is Swift 6 vs 5 mode: annotations port verbatim. `ArabicText` and `QuranBuilder` stay in Swift 6 mode as packages. `onGeometryChange` (`AyahPanel` :116, `TafsirSection` :100) is fine at iOS 17: Mushaf builds against the same 17.0 / 15.0 targets. |
| **T14 (new)** V2 fonts in a public clone | `QuranData/…/madaniV2` folder reference; `.gitignore`; `Tools/add_quran_data_phase.rb` | A synchronized group flattens resources (**checked:** `Resources/Fonts/Quran/*.ttf` land at the bundle root today), so the 604 fonts need a **folder reference** outside `ThawabForGod/` to keep the `madaniV2/` path `FontPackStore` reads. A folder reference to a missing folder is expected to fail the copy phase in a public clone (to confirm in M2). Fix either way: commit a placeholder `README.md` in the folder and change the M0 ignore rule from `madaniV2/` to `madaniV2/*` + `!madaniV2/README.md` (M2). |
| **T15 (new)** One `manifest.json`, two profiles | `Q/Data/Packs/ContentPackStore.swift`; `QB/.../Packs.swift` | Mushaf bundles `Packs/manifest.json`; the two profiles would write different manifests to one committed path, so every local full build would dirty git. Packs already carry a `pack` table (id, kind, language, name, author, direction, version, source, licence): the store discovers packs by scanning, and the manifest becomes a build report, not a resource. Synchronized groups also flatten `Packs/`, so discovery is by file prefix (`translation-`, `tafsir-`, `surah-info-`). |
| **T16 (new)** Tafsir silence | `Q/Data/Packs/TafsirRepository.swift`; `Q/Tafsir/TafsirSection.swift` | Mushaf's packs give *every* ayah a group owner; Jalalayn deliberately has no row for 226 verses, and Noor's `TafsirViewModel.Phase.silent` exists so a neighbour's gloss is never shown. The ported repository returns `nil` for an ayah with no row and no covering group, and the section shows "this commentary has no note here". Noor's 226-verse test carries over. |
| **T17 (new)** Search highlighting | `Q/Domain/QuranSearch.swift` (`SearchHighlight`); `Q/Search/QuranSearchView.swift` | Noor's CLAUDE.md says Quran results are *not* highlighted (index offsets ≠ vowelled-text offsets). Mushaf highlights by re-matching folded words on the displayed text. **Q4.** |

---

## 5. Rule violations quoted by the scouts, by the milestone that fixes them

(Line numbers are in the Mushaf file unless the path says otherwise. DEBUG-only harness code is dropped rather than fixed, so it is not repeated here.)

**M2 (data):** `Packages/QuranText/Package.swift` macOS 14 < 15 · normalizer divergences (§4 T3) · `.gitignore` ignores `Packages/`.

**M3 (domain/data):**
- Own database queues: `QuranDatabase.swift:28–31`, `TranslationRepository.swift:20–26`, `SurahInfoRepository.swift:45–48`, `SQLiteSearchRepository.swift:59–62`.
- `ContentPack.swift:149` duplicates `AppLanguage` (reads `Bundle.main`).
- Numbers via `NumeralSystem`: `ContentPack.swift:184–190`.
- `LocalizedStringResource` titles: `Search.swift:15–21`.
- Noor side: `Core/Theming/SurahNameGlyph.swift` and `Views/SurahHeaderView.swift:25` (`.custom` bypassing `.appFont`) are deleted, and `ReaderSettingsSheet.swift:356, :404` (literal sizes) and `:321, :350` (hard-coded Arabic) go with the rest of that file.

**M4 (renderer, themes, settings):**
- Literal colours: `ReaderTheme.swift:24–69, :89–90, :109`.
- Literal / system font sizes: `SurahHeaderGlyph.swift:49`, `SurahNameGlyph.swift:24`, `QuranFont.swift:57, :63`, `MarginMarkerLabel.swift:21`.
- `NumeralSystem`: `MarginMarkerLabel.swift:31–39`, `MushafPageView.swift:90, :99–101`.
- Raw interpolation: `MushafPageAccessibility.swift:149`.
- `AnyView`: `MushafPageAccessibility.swift:200–204`.
- Singleton: `PageMetricsCache.swift:13`.
- `UserDefaults` blob: `ReaderStateStore.swift:50–70` (`"readerState"`).
- Strings: `MarginMarkerLabel` 6, `MushafPageAccessibility` 6, `MushafPageView` 1.

**M5 (screens):**
- Strings (approximate counts): `ReaderSettingsView` 26, `AyahPanel` 17, `AyahContextMenu` 14, `ReaderToolbar` 9, `ReaderRootView` 3 (:20, :22, :259), `TafsirSection` 3, `TafsirReaderView` 2, `TranslationTextView` 2, `SeparatedReaderView` 1 (:77), `LibraryView` 24, `SurahInfoView` 13, `SearchView` 22, `ContentPacksView` 11, `AboutView` 24.
- Literal colours: `AyahContextMenu.swift:117–120`, `LibraryView.swift:76` (`.red`), `ContentPacksView.swift:116` and `AboutView.swift:113` (`.secondary`).
- Literal sizes: `AyahContextMenu.swift:30`, `AyahPanel.swift:37–38`, `TafsirSection.swift:128–134`, `LibraryView.swift:315`, `SurahInfoView.swift:25, :57`, `SearchView.swift:316`; system fonts `TafsirTextView.swift:42`, `TranslationTextView.swift:26`; system text styles throughout Library → `.appFont`.
- `NumeralSystem`: `AyahActions.swift:16`, `AyahPanel.swift:383`, `ReaderSettingsView.swift:129–138`.
- `UserDefaults`: `RecentSearchStore.swift:9` (`"recentSearches"`).
- Copy that names khatmah: `AboutView.swift:30`.

**M6 (user data):**
- Own `ModelContainer`: `SwiftDataUserDataRepository.swift:105–118`.
- Strings: `BookmarksView` 14, `NoteEditorView` 8, `BookmarkList.swift:12–13, :25–27`, `UserData.swift:38–45` (`HighlightColor.title`).
- Date not via `LocalizationManager`: `BookmarksView.swift:180`.
- Sizes: `BookmarksView.swift:192`, `NoteEditorView.swift:28`.

**M7 (platforms, widgets):**
- Strings: `KeyCommands.swift:24–36, :107`, `TabletopBottomView` 3 (:21, :61, :76), `MushafWidgets.swift:65–66, :84–85`, `WidgetViews.swift` 9.
- Numbers: `TabletopBottomView.swift:49`, `WidgetPublisher.swift:77`, `WidgetSnapshot.swift:61`, `WidgetViews.swift:29–30, :98–100`.
- Literal RGB / sizes: `WidgetViews.swift:229–232, :146–153, :175`.
- `UserDefaults`: `WidgetSnapshot.swift:153–168`.
- Own router: `WidgetLink` (`WidgetSnapshot.swift:115–136`).
- `#if os(macOS)` in a view: `ReaderWindow.swift:61–63` (dropped with the file).

---

## 6. Work split per milestone

Only the main agent runs `xcodebuild`, makes the architecture and concurrency calls, reviews every subagent diff, and commits. Subagents run in parallel only on disjoint file sets. The porters work *after* the main agent has ported the code under test or the file they localize. From M2 on the session can call the agents by name; in M1 they ran as `general-purpose` + `model: haiku` with the scout prompt verbatim, because `.claude/agents/` only loads at session start.

| M | Main agent | `test-porter` (parallel batches) | `l10n-porter` (parallel batches) |
|---|---|---|---|
| **M2** | `.gitignore` fixes (T3, T14); `AT` package + idempotent `Tools/add_arabic_text_package.rb`; `ArabicSearchQuery` on top of it; `QB` port with both profiles, Tanzil inputs, Jalalayn pack; V2 folder reference + Release guard via `Tools/add_quran_data_phase.rb`; `FontRegistrar` exclusion; size report; Corpus README; regenerate `quran.sqlite` | A: `QuranTextTests` → `AT/Tests` · B: `QB` integrity tests (6 files) · C: `FTS5SpikeTests` | — |
| **M3** | Move `QuranStubError` and `VerseReference`; delete legacy feature + dead keys/fonts/settings; placeholder tab; Domain + Data port; container wiring | A: `DomainTests`, `SQLiteQuranRepositoryTests`, `MarginMarkerTests`, `MushafStyleTests` · B: `SearchTests` · C: `TafsirRepositoryTests`, `TranslationRepositoryTests` | — |
| **M4** | Renderer, `FontPackStore`, `PageMetricsCache`, `FoldGeometry`, themes as assets, `QuranReaderSettings` + keys, golden/perf runs | A: `FontPackStoreTests`, `FontAndGlyphTests` · B: `PageMetricsCacheTests`, `PageUnitTests`, `RendererSelectionTests` · C: `ContrastTests` | A: `MarginMarkerLabel`, `MushafPageView`, `MushafPageAccessibility` |
| **M5** | Coordinator + routes, reader screen, separated mode, Library root, search, panel, tafsir/translation, settings sheet, Sources, tab-bar hiding | A: `AppRouterTests`→`QuranCoordinatorTests`, `AyahPanelTests` · B: `LibraryTests`, `ContentPackSelectionTests`, `LocalizationDefaultsTests` · C: `TafsirChoiceTests`, `TafsirMarkupTests`, `TranslationMarkupTests` · D (UI, XCTest, if Q2 allows): `ToolbarActions` + `LaunchTests` | A: Library + SurahInfo · B: Search · C: AyahPanel + AyahContextMenu + AyahActions · D: Reader view + toolbar + settings sheet + ContentPacks · E: Tafsir + Translation views + Sources |
| **M6** | Records, `@ModelActor` repo, `QuranUserDataStore`, continue reading on Home + Library, `RecentActivity` | A: `BookmarkListTests`, `UserDataRepositoryTests` · B (UI): `BookmarkTests`, `StudyFeatureTests` | A: Bookmarks + NoteEditor + `BookmarkList` + `HighlightColor` |
| **M7** | `QuranCommands` focus scoping, key/wheel paging, landscape, fold + tabletop, widgets, App Group font, `DeepLink` cases | A: `KeyCommandTests`, `WheelAccumulatorTests` · B: `WidgetTests` · C (UI): `KeyboardTests`, `FoldPanelTests`, `TabletopTests`, `WidgetLinkTests` | A: `QuranCommands` + `TabletopBottomView` · B: widget views + providers |
| **M8** | Cleanup, docs, licences, size/offline proof, full suites on iOS and macOS | — | — |

---

## 7. Open questions and estimate

**Q1 — T12.** The adhkar reader has no fold implementation to merge (it uses `ArrangementView`). Proposal: `MushafFold` moves to `Core/Layout/FoldGeometry` as the one fold *measurement* in the app; the adhkar keeps `ArrangementView`; T12 is recorded as "one helper, one caller". The alternative is rewriting the adhkar onto the helper, which I'd advise against: it trades a system container for hand measurement.

**Q2 — UI-test harness.** Mushaf's UI tests drive the app through 34 `-debug*` launch arguments (`DebugLaunchOptions` and its extensions, 580 lines across six files). Options: (a) port a slim DEBUG-only `QuranLaunchOptions` with the ~12 hooks the kept tests use (mode, page, surah, panel, theme, settings, bookmarks, search, library, tafsir, reset/seed user data); (b) drive UI tests through `noor://` deep links plus an in-memory store flag only, and rewrite tests that need more; (c) port no UI tests until M8. I recommend (a), compiled out of Release.

**Q3 — "Golden pages match mushaf-final".** No reference images exist; Mushaf's golden-pages script only captures. Proposal: at M4, capture the same page set on iPhone SE / iPad / Mac from the reference project and from the branch, and attach both sets to the M4 report for your visual sign-off (no pixel diff, since the font rasterisation path is identical but chrome differs). OK?

**Q4 — T17, search highlighting.** Keep Mushaf's highlighting (it re-matches folded words against the displayed text), or keep Noor's documented "no highlight" rule? Recommendation: keep Mushaf's; it is tested (`SearchTests` highlight cases). Noor's rule was a consequence of its index, not a design choice, and M8 updates `CLAUDE.md`.

**Q5 — Fallback pages.** In the Tanzil build, Mushaf mode is hidden (T4) but the Library has a Page tab. Tanzil's page table is also 604 pages, but 56 verses start one page away from the V2 layout (T4). Show the Page tab in the fallback, or hide it with Mushaf mode? Recommendation: hide it, so a page number never means two things.

**Q6 — `UIT/ScreenshotTourTests.swift`.** It is marked "TEMPORARY … Not to be committed" but is in the tree, and it taps the old Quran screens. Delete it at M3?

**Q7 — Pre-existing test failure (not caused by M0).** `UserNotificationServiceTests.aReminderSurvivesAnArtworkFileThatIsNotThere` fails on this simulator (Xcode 27.1, iOS 26.5): `UNNotificationAttachment` now *accepts* a URL to a missing file instead of throwing, so the reminder ships with a dangling attachment. The fix (check the file exists before building the attachment) is a small change to `Core/Notifications`, outside the migration. Fix it on `Development` first, or as an `M2.0` commit on this branch?

**Q8 — Branch base.** `quran-migration` was cut from `Development` (`9f91c57`), not `main`: `main` is 11 commits behind and lacks the code the plan's T1/T12/D4 operate on. The plan's step 4 ("merge after M8") therefore merges into `Development` (or `main` after `Development` lands). Please confirm.

**Q9 — Ayah of the day.** `QuranData/curated/ayah-of-the-day.txt` (147 lines, 125 entries) is still "draft, to be reviewed by Saad", and `WidgetTests` asserts a reviewed status. It needs your review before M7 can be green.

### Estimate

The plan's 8–10 sessions holds, with one more likely: **9–11 sessions.**

| M | Sessions | Why |
|---|---|---|
| M2 | 1.5 | Two profiles, a Tanzil loader ported from Python, two `.rb` project scripts, a package |
| M3 | 1 | Mostly moves; the deletion collateral is now mapped |
| M4 | 1.5–2 | Renderer + assets + perf/golden proof |
| M5 | 2 | ~170 strings, ~15 screens, navigation |
| M6 | 1 | |
| M7 | 1.5 | Widgets + commands + fold, three platforms |
| M8 | 0.5–1 | |
