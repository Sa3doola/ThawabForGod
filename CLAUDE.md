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

Foundation work in progress, built one layer at a time: **design system (done)** → localization → persistence → networking. `Item.swift` and `ContentView.swift` are leftover Xcode "SwiftData App" template scaffolding — replace them, don't build around them. The app root currently shows `DesignSystemGallery` (a developer screen) instead of `ContentView`; the persistence step restores a real root.

## Platforms & toolchain

- Deployment targets: **iOS/iPadOS 17.0, macOS 15.0**. `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone + iPad). Do not use APIs newer than these.
- Concurrency: **no data races.** Prefer async/await and structured concurrency; do not add Combine or completion-handler APIs to new code.
- Actual build settings today: `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`. Strict concurrency checking is **not** yet set to `complete` and the language mode is **not** yet Swift 6 — write code as if it were (explicit isolation, `Sendable` where values cross boundaries) so the flip is a non-event.
- Because the module default is `MainActor`, declarations are implicitly main-actor-isolated unless annotated. Background work needs an explicit `nonisolated` or a detached task; don't assume a type is concurrency-free just because it carries no annotation. UI-facing types should still say `@MainActor` explicitly where it documents intent.
- No linter, formatter, CocoaPods, or CI. No SPM dependencies yet — Adhan will be the first.

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

**All user preferences go through `SettingsStore`** (`Core/Settings/Domain`) — a `nonisolated` key/value protocol with a `UserDefaults` implementation and an `InMemorySettingsStore` for previews and tests. Add a case to `SettingsKey`; never touch `UserDefaults` directly and never invent a second settings path.

**Design system: `Core/Theming`.** Views read `@Environment(\.theme)` for colour and use `.appFont(_:weight:)` for type — never a literal `Color`, a hex, or `.font(.system(size:))`. `AppColor` is the only file naming asset colours; the `Colors/` and `Accents/` asset groups provide a namespace so generated symbols don't collide with SwiftUI's `primary`/`separator`. Each colour set carries light and dark values, so no view branches on `colorScheme`. `ThemeManager` (`@Observable @MainActor`) owns the accent and appearance choices and is applied once at the root via `.themed(_:)`.

**One codebase, two platforms.** Platform differences are handled inline with `#if os(macOS)` / `#if os(iOS)`. The template's `ContentView` wraps its content in a `fileprivate NavigationViewWrapper` that expands to `NavigationSplitView` on macOS and passes through on iOS — reuse that seam when a screen needs divergent navigation.

**Persistence is SwiftData, wired at the app root.** `ThawabForGodApp` builds a single `ModelContainer` from an explicit `Schema([...])` and injects it via `.modelContainer(...)`. Every new `@Model` type must be added to that `Schema` array or it will not be persisted. The template reaches the store directly from views via `@Environment(\.modelContext)` and `@Query` — that is scaffolding, not the pattern: new feature code goes through a repository protocol in Domain with a SwiftData-backed implementation in Data, injected by `AppContainer`. Previews use an in-memory container (`.modelContainer(for:inMemory: true)`) so they don't touch the on-disk store; match that in new previews and in any test that needs a context.

## Conventions

- **DI:** constructor injection, assembled in `AppContainer`. No singletons for app logic (system wrappers like `NotificationCenter` are fine behind a protocol).
- **State:** Observation framework (`@Observable`) for ViewModels; `@State` / `@Binding` / `@Environment` in views. Do not use `ObservableObject` / `@Published` in new code.
- **Views:** keep `body` small. Extract any subview over ~60 lines or reused. Avoid `AnyView` — use `@ViewBuilder` or a `switch` over an enum instead.
- Every repository/service has a protocol (Domain) + an implementation (Data).
- **Localization:** Arabic + English via String Catalogs; build every screen to mirror for RTL. Never hardcode user-facing strings.
- **Numbers:** route through a formatter that switches Arabic-Indic / Latin digits.

## Prayer times

Computed on-device with the **Adhan** library (MIT) — no API. The engine lives in a shared type in `Core`, to be extracted into a Swift package later. Location via CoreLocation; reverse-geocode only for the display name.

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
- Don't hand-edit `project.pbxproj` or change signing settings. The project uses file-system synchronized groups, so new files are picked up automatically — just create them in the right folder, no target registration needed.
