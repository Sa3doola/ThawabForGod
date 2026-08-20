# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

**Noor** — a multiplatform Islamic app: iPhone, iPad, and macOS from a single SwiftUI codebase. (The Xcode project, scheme, and bundle are still named `ThawabForGod`; treat "Noor" as the product name until the target is renamed.)

**Offline-first: every core feature must work with no network.** The project is open source and meant to read as a clean learning reference — favour clarity over cleverness.

## Skills to use

This project is SwiftUI + Swift Concurrency, so two skills apply to most work here. Invoke them via the `Skill` tool before writing or reviewing code — don't work from memory when one of them covers the task.

- **`swiftui-expert:swiftui-expert-skill`** — any SwiftUI work: new views, state management (`@State`/`@Observable`/`@Environment`), view composition, navigation (including the macOS/iOS split below), Liquid Glass adoption, and performance investigation with Instruments `.trace` files.
- **`swift-concurrency:swift-concurrency`** — anything touching async/await, actors, `Task`, `Sendable`, or isolation. This matters more than usual here because `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes every declaration implicitly main-actor-isolated, so background work needs deliberate reasoning about the isolation boundary rather than a reflexive `@MainActor`.

When a change is both — e.g. a view that kicks off async loading — consult both: SwiftUI skill for the view shape, concurrency skill for where the work runs.

## Project state

Foundation layers: design system, localization (strings, digits, clock times), persistence, networking, settings, location, notifications — each registered in `AppContainer`.

These vertical slices are built:

- **Home / prayer times** — `Core/PrayerTimes` (Domain + Data, Adhan-backed) and `Features/Home`. Times are computed on device; the engine also supplies the Qibla bearing, so the Qibla slice reuses it rather than adding a second copy of the maths.
- **Onboarding** — `Features/Onboarding`, gated on a persisted completion flag. `AppRouter` reads that flag once at launch and `RootView` switches between the two.
- **Adhkar** — `Features/Adhkar`, the first feature to read the bundled corpus.
- **Tasbih** — `Features/Tasbih`, the first to write user data. Phrases from the corpus, counts into SwiftData through a `@ModelActor`, with the live count kept in memory and written out at lap boundaries and on the way out rather than on every tap.
- **The 99 names** — `Features/NamesOfAllah`, read-only throughout, with an in-memory search over the loaded rows.
- **Reminders** — `Core/Notifications`, local notifications on a rolling window over the same `PrayerTimeRepositoring` Home reads. No feature folder: it has one screen's worth of UI (five toggles in Settings) and no screen of its own. See the section below for the 64-notification cap that shapes it.
- **Settings** — `Features/Settings`, the screen that drives everything above. It stores **nothing**: each row writes through to the manager that already owns that preference (`ThemeManager`, `LocalizationManager`, `CalculationSettings`), all of which persist through `SettingsStore`. `SettingsViewModel`'s properties are computed with setters rather than stored, so reading one in a view observes the *owner* and a change made anywhere shows through. There is deliberately no `AppSettings` aggregate and no second repository: an all-fields `save(_:)` would write keys the user never chose, which is the one thing this project's settings notes forbid.

**Navigation is a tab bar** (`App/MainTabView`, `App/AppTab`), which is what the toolbar's Library menu had been a holding pattern for. Four tabs: **Home** (prayer times), **Quran** (a placeholder until Phase 2 fills it), **Adhkar**, and — on iOS only — **Settings**. Each tab owns its own `NavigationStack`, so switching tabs preserves where each one was left and nothing is nested inside anything else. The selection lives on `AppRouter.selectedTab` rather than in a `@State`, so a later deep link (a tapped reminder, a widget) can move between tabs without reaching into the view hierarchy.

The line between a tab and a push: a **tab** is a place the user returns to and expects to find where they left it; a **push** is a visit that ends by going back. So the Qibla, the tasbih and the 99 names stay in Home's toolbar — Qibla as its own button, the other two behind the **Library** menu — and go onto the Home tab's stack. On macOS there is no Settings tab, for the same reason there was never a toolbar gear: that build reaches the same screen through the `Settings` scene and ⌘,, and a tab would be a second door to the same room.

- **The Quran** — `Features/Quran`, the first slice of Phase 2 and the first feature with a corpus file of its own. `quran.sqlite` (Tanzil's Uthmani text, built by `Tools/CorpusBuilder/build_quran_db.py`) carries the 114 chapters, all 6,236 verses, the juz/hizb/rub-el-hizb divisions, mushaf pages, sajda markers, a search-normalized copy of each verse and two FTS5 indexes. The slice repeats the shape the other corpus readers have — Domain entities and `QuranRepositoring`, a GRDB repository in Data, one view model and a coordinator above them — reading through a *second* `CorpusDatabase`, since `CorpusDatabase` is constructed with a resource name and knows nothing about what is in the file.

  The tab holds a segmented control (chapters / parts) rather than a second `TabView`, and both lists push into one `ReaderView`: a part is a span of verses that crosses chapter boundaries, not a different kind of screen. The reader draws a chapter heading only when the span covers more than one, and the basmala only where the span actually contains that chapter's first verse — juz 2 opens at 2:142, and a heading there would say the reader is at the start of Al-Baqara.

  **Reading customization** is the second slice, and it sits mostly in `Core/Theming` rather than in the feature: `ReaderPaper` and `ReaderTypography` are Domain enums/values, `ReadingPalette` and `ReadingStyle` are the resolved pair a page is drawn with, and `Theme.reading(_:)` is the lookup — so `AppColor` stays the only file naming an asset colour. What belongs to the Quran is `ReaderSettings` (the `@Observable` preferences object, alongside the view model) and `ReaderSettingsSheet` (the panel). Three `SettingsKey`s, no SwiftData: these are preferences.

  Three details worth keeping. **The papers are fixed**, carrying the same value in light and dark — a reader who chose parchment for the evening did not ask for it to turn white when the appearance schedule flips — and a named paper replaces the *accent* too, because the app's amber is chosen against the app's background and washes out on cream. **The panel has no preview in it**: it opens at `.medium` with `presentationBackgroundInteraction` enabled, so the reader's own verses above it are the preview and stay scrollable. **The size is a point size**, the one place the app departs from `AppTextStyle` — but Dynamic Type still multiplies it, in `ReadingFontModifier`, because SwiftUI has no system-font equivalent of `Font.custom(_:size:relativeTo:)` and `@ScaledMetric` seeded with `1` is what closes that gap.

  **Bookmarks and last-read position** are the third slice, and the Quran's first user data. `QuranBookmark` is keyed on its `VerseReference` — the verse *is* the identity, so keeping one twice is idempotent and cannot produce two identical rows — and `ReadingPosition` is a separate single row rather than a flag on a bookmark, because a "current" flag on a list means every write has to clear the flag on whatever held it before. Both go through one `QuranProgressRepositoring` and one `@ModelActor`, with `QuranBookmarkRecord` and `ReadingPositionRecord` registered in `PersistenceController.schema`. Uniqueness on `(surah, verse)` is the *repository's* job: `@Attribute(.unique)` is per-property and `#Unique` over several is iOS 18.

  Two things this slice learned on device rather than on paper. **A `LazyVStack` is only lazy in its direct children** — the reader used to nest a whole chapter in one child, so all 286 verses of Al-Baqara were built before the first frame, every `onAppear` fired at once, and scrolling fired none. That is why `Reading.items` flattens the span into headings, basmalas and verses as siblings. And **the position write races the list reload**: popping the reader fires its `onDisappear` while `QuranListView` re-runs `loadProgress()`, so the write is parked on a `Task` that `loadProgress()` awaits, or "continue reading" goes on naming the verse the reader opened at.

  Next, in order: translations, search over the FTS5 indexes already built, then tafsir. Translations are **blocked on licensing, not on code** — Tanzil, which the Arabic text comes from, licenses its translations non-commercial only, and `quranenc.com` does not publish its terms on the page. Nothing gets bundled until that is settled; see `Resources/Corpus/README.md` for the standard this project holds source data to. A bespoke Uthmani face is deliberately *not* in that list yet — `AppFontProviding.readingFont(size:)` is the seam it would arrive through, but it needs a licensed font file bundled and registered, which is its own slice.

`DeveloperGallery`, `DesignSystemGallery` and `LocalizationGallery` are all gone — Settings exercises accent, appearance, language and digits on a real screen, which is what the galleries stood in for.

## Platforms & toolchain

- Deployment targets: **iOS/iPadOS 17.0, macOS 15.0**. `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad). Do not use APIs newer than these.
- Concurrency: **no data races.** Prefer async/await and structured concurrency; do not add Combine or completion-handler APIs to new code.
- Actual build settings today: `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`. Strict concurrency checking is **not** yet set to `complete` and the language mode is **not** yet Swift 6 — write code as if it were (explicit isolation, `Sendable` where values cross boundaries) so the flip is a non-event.
- Because the module default is `MainActor`, declarations are implicitly main-actor-isolated unless annotated. Background work needs an explicit `nonisolated` or a detached task; don't assume a type is concurrency-free just because it carries no annotation. UI-facing types should still say `@MainActor` explicitly where it documents intent.
- No linter, formatter, CocoaPods, or CI. Two SPM dependencies: **Adhan** (`batoulapps/adhan-swift`, MIT, upToNextMajor from 1.5.0) for prayer times, and **GRDB** (`groue/GRDB.swift`, MIT, upToNextMajor from 7.0.0) for the read-only corpus. Xcode has no CLI for adding packages, so if another is ever needed, add it through Xcode's UI — or programmatically with the `xcodeproj` Ruby gem, which writes the same structures Xcode does. Never by hand.

## Architecture — Clean Architecture, MVVM-C

Layer folders under the target root (`ThawabForGod/`):

- `App/` — composition root: app entry (`ThawabForGodApp`), `AppContainer` (manual DI), routing.
- `Core/` — cross-cutting infra: theming, localization, persistence, networking, DI, location, notifications, formatters.
- `Features/` — one folder per feature: `Views` (SwiftUI) + `ViewModel` + `Coordinator`, plus that feature's Domain/Data types.
- `Resources/` — assets (`Assets.xcassets`), localized strings, bundled data, fonts.

**Dependency rule: Features → Domain ← Data.** Domain is pure Swift — no SwiftUI or UIKit imports. Wire concrete types only at the composition root.

Each `Core` subsystem repeats that split:

```
Core/<Subsystem>/
  Domain/   protocols + entities — pure Swift, no SwiftUI / SwiftData / URLSession
  Data/     implementations — UserDefaults, SwiftData, URLSession
  UI/       SwiftUI glue — @Observable @MainActor managers, @Entry environment values, modifiers
```

**All user preferences go through `SettingsStore`** (`Core/Settings/Domain`) — a `nonisolated` key/value protocol (string, bool, double) with a `UserDefaults` implementation and an `InMemorySettingsStore` for previews and tests. Add a case to `SettingsKey`; never touch `UserDefaults` directly and never invent a second settings path. **Only write a key the user actually chose.** A stored preference outranks the device forever, so persisting a computed default silently converts "no preference" into a choice that cannot be undone — onboarding used to seed `language`, `numberSystem`, `accentPalette` and `appearance` from whatever was in effect at first launch, which left anyone who set the app to Arabic in iOS Settings stuck in English. It now writes only what it asked about (calculation method, madhab, coordinates), and `LocalizationManager` / `ThemeManager` fall back to the device until the user picks in Settings. Settings keeps that rule: it writes one key per choice made, through the owning manager, never a whole `AppSettings` record at once. Note the `object(forKey:)` casts in the `UserDefaults` implementation: `bool(forKey:)` and `double(forKey:)` cannot tell "false"/"0" from "unset", and 0 is a valid latitude.

**Design system: `Core/Theming`.** Views read `@Environment(\.theme)` for colour and use `.appFont(_:weight:)` for type — never a literal `Color`, a hex, or `.font(.system(size:))`. `AppColor` is the only file naming asset colours; the `Colors/` and `Accents/` asset groups provide a namespace so generated symbols don't collide with SwiftUI's `primary`/`separator`. Each colour set carries light and dark values, so no view branches on `colorScheme`. `ThemeManager` (`@Observable @MainActor`) owns the accent and appearance choices and is applied once at the root via `.themed(_:)`.

**One codebase, two platforms.** Platform differences are handled inline with `#if os(macOS)` / `#if os(iOS)`. Both builds must stay green — check macOS too, not just the simulator.

**Localization: `Core/Localization`.** **The language is the system's, not the app's.** The bundle ships `ar.lproj` and `en.lproj`, so iOS gives the app a *Preferred Language* row of its own in Settings → Apps → Noor, and picking there relaunches the process. Settings shows the current language and opens that page (`UIApplication.openSettingsURLString`); it does not offer a picker. There is deliberately **no `SettingsKey.language`** — a stored one would outrank the system's choice forever.

An in-app switcher was built and then removed, and it is worth knowing why before anyone rebuilds it: `Form` and `List` are UIKit-backed and fix their right-to-left mirroring when the backing view is created. Flipping `\.layoutDirection` under a live one leaves that transform in place, so the content mirrors twice and **every glyph renders backwards** — reproduced on device by switching Arabic → English while standing on Settings. Rebuilding the subtree with `.id(layoutDirection)` did not reliably clear it either. So `.localized(_:)` now sets *only* the manager in the environment: no `\.locale`, no `\.layoutDirection`, no `.id`. The system applies both at launch, correctly, for the whole hierarchy.

What `LocalizationManager` still owns is what a `Locale` cannot express: digits (`NumberSystem`) and hour cycle (`ClockFormat`, whose `.system` case keeps deferring to the locale). Strings still go through `l10n.string(_:)` — not to switch at runtime, but because `L10nKey` makes a missing key a compile error. Keys live in `Resources/Localizable.xcstrings`; add a case and both translations together (a test reads each `.lproj` directly and asserts every key resolves in both). Numbers go through `l10n.string(_ value: Int)`, never interpolation. `AppLanguage.current(in:)` reads `preferredLocalizations`, and views that pin Arabic scripture or an LTR compass still set `\.layoutDirection` locally on that leaf — which is safe, because those views are created with it rather than having it changed underneath them.

**Persistence: `Core/Persistence`, SwiftData, mutable user data only.** Bookmarks, counts, progress — the read-only corpus is a separate bundled store (see below) and must not be added to this schema. `PersistenceController` owns the single `ModelContainer` (every new `@Model` type must be listed in its `Schema` or it will not be persisted) and is injected into the environment at the root. Features depend on repository protocols in Domain (`BookmarkRepository`), implemented in Data by a `@ModelActor` actor that runs off the main actor. `@Model` classes stay inside Data and never cross an actor boundary — domain value types do. Repositories buy safety at the cost of `@Query`'s live updates: callers re-fetch after a mutation. Tests and previews build a container with `PersistenceController(inMemory: true)`.

**Corpus: `Core/Persistence/Corpus`, GRDB over bundled SQLite files, read-only.** The app's unchanging content, in two files: `corpus.sqlite` carries one table set per feature (the adhkar, the tasbih presets and the 99 names) and `quran.sqlite` carries the Quran, which has a different upstream, a different licence and an order of magnitude more text. `CorpusDatabase` opens the file read-only and hands out one shared `DatabaseReader` through `CorpusDatabaseProviding`; a `DatabaseQueue`, not a `DatabasePool`, because a pool's concurrent readers need WAL and WAL needs sidecar files that cannot be written beside a bundle. Only Data-layer repositories may depend on that protocol — it names a GRDB type, so it is infrastructure rather than Domain, and `AdhkarRepository` is the one file in its feature that sees SQL. Reads land off the main actor for free: GRDB dispatches the body of `read` onto the database's own queue whatever actor asked. The databases are generated by a documented build step, never hand-edited — see `Resources/Corpus/README.md`, which also carries the standing warnings that **neither the adhkar text nor the English meanings of the 99 names have been verified, and must not ship in V1 until they have**. That file records how each data set was sourced and, for the names, which candidate was rejected and why — a set that was MIT-licensed but AI-generated turned out to have dropped a name and shifted the rest, which is the argument for cross-checking rather than taking the first licensed file.

**Networking: `Core/Networking`, optional by design.** No core feature may require it. `HTTPClient` (Domain protocol, `URLSessionHTTPClient` in Data) does GET into a `Decodable`, mapping everything onto `HTTPError` — `.transport`, `.status`, `.decoding`, plus `isRecoverable` for retry decisions — and re-throws `CancellationError` for cancelled tasks. `ReachabilityMonitor` (`@Observable @MainActor`, `NWPathMonitor`) exists to gate online-only affordances, never to block core features. Tests drive it through `MockURLProtocol` on an ephemeral session; that suite is `.serialized` because the mock's handler is class-level state.

## Conventions

- **DI:** constructor injection, assembled in `AppContainer`. No singletons for app logic (system wrappers like `NotificationCenter` are fine behind a protocol).
- **State:** Observation framework (`@Observable`) for ViewModels; `@State` / `@Binding` / `@Environment` in views. Do not use `ObservableObject` / `@Published` in new code.
- **Views:** keep `body` small. Extract any subview over ~60 lines or reused. Avoid `AnyView` — use `@ViewBuilder` or a `switch` over an enum instead.
- Every repository/service has a protocol (Domain) + an implementation (Data).
- **Localization:** Arabic + English via the String Catalog; build every screen to mirror for RTL. Never hardcode user-facing strings — add an `L10nKey` case. `Text(verbatim:)` is only for developer-facing screens.
- **Numbers:** route through `LocalizationManager` / `NumberFormattingService`, never string interpolation.

## Prayer times

Computed on-device with the **Adhan** library (MIT) — no API. `Core/PrayerTimes/Data/PrayerTimeEngine` is the **only file that imports Adhan**; everything above it speaks in domain entities (`Prayer`, `PrayerSchedule`, `Coordinates`, `CalculationConfig`), which is what keeps the library swappable and lets the whole slice be tested without it. The engine builds its own Gregorian calendar in the user's time zone — reading components through `Calendar.current` would hand Adhan Hijri numbers on a device set to the Islamic calendar.

Next-prayer roll-over (after Isha → tomorrow's Fajr) lives in `GetPrayerScheduleUseCase`, not in `PrayerSchedule`, because it needs a second day's times. `PrayerSchedule` answers only within its own day and returns `nil` past Isha.

Location via CoreLocation behind `LocationService` (`Core/Location`); reverse-geocode only for the display name. `CoreLocationService` is the only file that imports CoreLocation.

**Displayed times and countdowns go through `LocalizationManager.timeString(_:)` / `.countdownString(_:)`**, never `Text(date, style:)` — the digit system is a choice separate from the language, which a single `Locale` cannot express. Countdowns come back wrapped in Unicode directional isolates; without them the bidi algorithm reorders `6:03:49` into `6:0 3:49` on an Arabic screen.

## Reminders — `Core/Notifications`

**iOS keeps at most 64 pending local notifications per app and drops the rest silently**, which is the constraint the whole slice is shaped around. There is no scheduling a year of prayer times. Instead `PrayerReminderPlanner` (Domain, pure) plans a rolling ten-day window — 10 × 5 obligatory prayers = 50, fourteen spare — and `refreshSchedule()` clears and refills it. Sunrise never gets a reminder; it ends Fajr's window rather than starting a prayer.

Reminders carry **stable identifiers** (`prayer-reminder.2026-06-15.fajr`), which is what makes a refresh idempotent: re-adding under a pending identifier replaces it, so overlapping refreshes converge instead of doubling.

The window is refilled from `RootView`'s `.home` branch — `.task(id:)` on a key of config + enabled prayers + **language**, plus `scenePhase` returning to `.active`. The language belongs in that key because notification text is resolved when a reminder is *scheduled*, not when it is delivered. Triggers live at the composition root; nothing in a feature calls `refreshSchedule()`. Refills only happen while the app is open — `BGTaskScheduler` is a later slice, and there is a TODO at the foot of `UserNotificationService` saying so.

**No coordinates, no reminders.** Home falls back to Makkah so it has something to draw; a reminder cannot, because a notification firing at Makkah's Maghrib on a phone in London arrives while nobody is looking at the screen to notice it is wrong — the Qibla slice's argument, only stronger.

`UNUserNotificationCenter` sits behind `NotificationCenterClient` (Data, since it names UN types) so tests use a fake and never touch the real centre. `NotificationService` stays the single place authorization is asked for or read, and speaks the app's own `NotificationAuthorization` rather than `UNAuthorizationStatus` — Domain does not import UserNotifications.

## Build & test — run these to verify every change

Only one scheme exists: `ThawabForGod`. `SDKROOT = auto` with `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`, so a `-destination` is effectively required — without one, `xcodebuild` picks a platform on its own.

Build for simulator:

```bash
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Build for macOS:

```bash
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=macOS' -quiet
```

Run all tests (unit + UI):

```bash
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

Skip the slow UI target while iterating:

```bash
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -skip-testing:ThawabForGodUITests -quiet
```

Run a single test — the path is `Target/Suite/testName`:

```bash
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ThawabForGodTests/ThawabForGodTests/example -quiet
```

Check Swift 6 cleanliness without changing the project file — the language mode is still 5.0, so strict-concurrency problems are otherwise invisible:

```bash
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_VERSION=6.0 -quiet
```

List available simulators — note that `name=iPhone 16` fails here because the destination defaults to the latest runtime (26.5), which has no iPhone 16:

```bash
xcrun simctl list devices available
```

**Always build after a change; fix warnings and errors before finishing.** Warnings count as failures — the build is currently clean on all four commands above.

## Tests

Two frameworks, deliberately: `ThawabForGodTests` uses **Swift Testing** (`import Testing`, `@Test`, `#expect`, `@MainActor` suites), `ThawabForGodUITests` stays on **XCTest** (`XCTestCase`, `XCUIApplication`). Write new unit tests with Swift Testing. Add tests for Domain use cases, services, and ViewModels.

`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` means imports are not re-exported: a test touching a SwiftUI type needs its own `import SwiftUI` even though the app target already imports it.

## Don'ts

- Don't invent SwiftUI / Foundation APIs. If unsure an API exists, check the docs or say so — never hallucinate a symbol.
- Don't use APIs newer than the deployment target (iOS 17.0 / macOS 15.0).
- Don't put SwiftUI / UIKit imports in Domain.
- Don't hardcode a colour, hex value, or font size in a view — go through `@Environment(\.theme)` and `.appFont(_:weight:)`.
- Don't hand-edit `project.pbxproj` or change signing settings. The project uses file-system synchronized groups, so new files are picked up automatically — just create them in the right folder, no target registration needed. (The String Catalog ships Arabic without touching `knownRegions`, which is still `(en, Base)` — verified in the built bundle.)
