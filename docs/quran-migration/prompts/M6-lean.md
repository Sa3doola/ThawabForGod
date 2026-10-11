# M5.8 + M6 (user data), lean mode

Run on Sonnet (`/model sonnet`), new session. Follow `QURAN_MIGRATION_PLAN.md` §4 "Lean mode". No test runs, no screenshots.

## Saad's answers to the M5 decisions (record them in each design note's "Decisions" section, one line each)
- M5.3: Copy/Share = original Arabic + [reference] + shown translations with names; tafsir pick session-only with the M5.6 default; a tap always selects; iPad portrait uses a sheet. All as designed.
- M5.4: translations only inline, tafsir in the panel; nothing after An-Nas.
- M5.5: السماوات fold and dropping the names scope: confirmed. Recent searches: in M6 (below). Result replaces Search: keep.
- M5.6: edited pack lists keep Mushaf's behaviour (a pack added later starts off); spread floor on every platform; "licence unsettled" rows until M8.

## M5.8 (small fix, no architect): make the test targets compile again
Saad runs the tests himself, so they must build. Fix only call sites in `ThawabForGodTests` / `ThawabForGodUITests` broken by M5.3-M5.7 (`QuranCoordinatorTests.swift:33` needs `search:`, the old `AyahPanelViewModel` / `QuranCoordinator` inits, and any others). Keep every assertion's meaning; where a behaviour changed by decision (e.g. the السماوات assertion was flipped in M5.5), say so in the commit. Use `xcodebuild build-for-testing` for iOS and macOS, filtered output, **don't run the tests**. Agents: implementer(main) · rules-checker(haiku) · reviewer(opus).
Also commit the pending `project.pbxproj` change alone first: it is Xcode's own normalisation (empty `exceptions`, package comment names), not a hand edit. Message: `Xcode project normalisation`.

## M6: user data
| Task | What |
|---|---|
| **M6.1** | Models + repositories: `QuranBookmark`, `QuranNote`, `QuranHighlight` (colour from the reader palette), `QuranReadingPosition` as `@Model`s added to `PersistenceController.schema`, behind `@ModelActor` repositories with protocols in Domain. Uniqueness enforced in the repository (iOS 17, no `#Unique`). Architect decides whether the generic `Core/Persistence/Data/BookmarkRecord` is reused, migrated or left alone: check who uses it first. Not on the App Store, so no `VersionedSchema`; say in the note what happens to a dev device's existing store. Port behaviour from Mushaf's user-data folder (read-only), minus backup and khatmah. |
| **M6.2** | Reader UI: bookmark toggle on the ayah panel and the page header; highlight colours and note editor from the panel; highlights drawn in both renderers (Mushaf highlighting rule kept, ayah-level); notes indicator on the ayah. |
| **M6.3** | Library **Bookmarks** list (bookmarks, notes, highlights; sort by Mushaf order or date; swipe to delete; open goes to the ayah). Reached from the Library toolbar. |
| **M6.4** | Reading position persisted (debounced, off main): the Library's Continue reading bar survives a relaunch (replaces the session-only source from M5.2), Home's continue-reading card, and a `RecentActivity` row per reading session that opens the ayah (M5.7's chain). Recent searches (`SettingsKey.quranRecentSearches`, last 10, clearable) in Search. |

Stop only for a Blocking item you can't fix or a decision for Saad; stop after M6.4 regardless.

**Stop report (short):** per task the commit hash, one line, and the `Agents:` line; decisions for Saad with recommendations; new Arabic to review; one combined manual checklist for M6 grouped by device and data mode, including "kill and relaunch" checks.
