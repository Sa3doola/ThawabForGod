# Noor

An offline-first Islamic companion app for iPhone, iPad, and Mac — one
SwiftUI codebase, Clean Architecture, built in the open as a reference for
native Swift development as much as for daily use.

> The Xcode project, scheme, and bundle are still named `ThawabForGod`; treat
> **Noor** as the product name until the target itself is renamed.

## Why this exists

Two goals, held at once:

1. **A prayer companion that works with the network off.** Prayer times,
   Qibla direction, adhkar, the 99 names, a tasbih counter, prayer reminders
   — every one of them is computed or read on-device. The network is an
   enhancement (a place name, a data refresh), never a requirement.
2. **A codebase worth reading.** Clean Architecture, MVVM-C, Swift
   Concurrency written as if strict checking were already on, and comments
   that explain *why* a line exists rather than what it obviously does. See
   [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Features

**Phase 1 — built:**

- **Prayer times** for any date, computed on-device with the
  [Adhan](https://github.com/batoulapps/adhan-swift) library, with a
  next-prayer countdown and a rolling window of local reminders
  (`BGTaskScheduler`-backed, so the window keeps refilling even if the app
  isn't opened).
- **Qibla** — compass, bearing, and distance to the Kaaba, from the same
  calculation engine that powers prayer times.
- **Onboarding** — permissions and calculation-method setup, gated on a
  persisted completion flag; nothing is asked for that a core feature
  doesn't need.
- **Adhkar** — morning and evening remembrance, read from a bundled,
  read-only corpus.
- **Tasbih** — an electronic counter over five conventional dhikr phrases,
  with counts persisted per lap.
- **The 99 Names of Allah** — read-only, with in-memory search over name,
  transliteration, and meaning.
- **Hijri calendar** — Gregorian↔Hijri conversion and Islamic event markers
  on Home.
- **Settings** — accent color, appearance, calculation method and madhab,
  digit system (Arabic-Indic/Latin), clock format, and per-prayer reminder
  toggles. The language itself follows iOS's own *Preferred Language*
  setting rather than an in-app switcher — see `CLAUDE.md` for why.

**Phase 2 (planned):** the Quran, verse-by-verse, with selectable tafsirs and
a customizable reading experience.
**Phase 3 (planned):** authentic hadith collections and a spaced-repetition
memorization mode across adhkar, the 99 names, and short surahs.

See [`Islamic_App_Architecture_Plan.md`](Islamic_App_Architecture_Plan.md)
for the full product and phasing plan.

## Tech stack

| | |
| --- | --- |
| UI | SwiftUI, one codebase for iOS/iPadOS 17+ and macOS 15+ |
| Concurrency | Swift Concurrency only — no Combine, no completion handlers, in new code |
| Architecture | Clean Architecture, MVVM-C, manual dependency injection |
| Prayer times & Qibla | [Adhan](https://github.com/batoulapps/adhan-swift) (MIT), on-device |
| Reference content | [GRDB](https://github.com/groue/GRDB.swift) (MIT) over a bundled, read-only SQLite corpus |
| Mutable user data | SwiftData |
| Preferences | A single `SettingsStore` protocol over `UserDefaults` |
| Notifications | `UNUserNotificationCenter` + `BGTaskScheduler`, behind protocols |
| Contextual help | TipKit |

## Getting started

Clone, open `ThawabForGod.xcodeproj` in Xcode, and run the `ThawabForGod`
scheme on any iOS Simulator or on **My Mac**. There is no server, API key, or
`.env` to configure — the app is fully usable offline from a fresh checkout.

Building from the command line:

```bash
# iOS Simulator
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# macOS
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=macOS' -quiet

# Tests (Swift Testing + XCTest)
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full command list (including
the Swift 6 strict-concurrency check), code conventions, and how to propose a
change.

## Architecture

Short version: `Features` depend on `Domain`, `Data` implements `Domain`,
and `AppContainer` is the one place concrete types meet. Every cross-cutting
subsystem under `Core/` repeats the same Domain/Data/UI split.

```
App/            Composition root — AppContainer (manual DI), app entry, routing
Core/           Cross-cutting infra: prayer times, location, notifications,
                persistence, theming, localization, settings, networking
Domain/         Pure Swift — entities, use cases, repository PROTOCOLS
Data/           Repository IMPLEMENTATIONS — SwiftData, GRDB, URLSession, CoreLocation
Features/       One folder per feature: Views (SwiftUI) + ViewModel + Coordinator
Resources/      Assets, localized strings, the bundled corpus
```

Full write-up, with diagrams, in [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Data & attribution

| Domain | Source | License |
| --- | --- | --- |
| Prayer times & Qibla | [batoulapps/adhan-swift](https://github.com/batoulapps/adhan-swift) | MIT, on-device |
| Adhkar | [Seen-Arabic/Morning-And-Evening-Adhkar-DB](https://github.com/Seen-Arabic/Morning-And-Evening-Adhkar-DB) | MIT |
| The 99 Names | Vendored & cross-checked from public data sets — see notes below | Unsettled, see notes |

**Nothing in the bundled corpus has had a full scholarly verification pass
yet.** This is an explicit, standing blocker on presenting any of it as
authoritative — read
[`ThawabForGod/Resources/Corpus/README.md`](ThawabForGod/Resources/Corpus/README.md)
before relying on or redistributing this content. That file documents, per
data set: what was cross-checked and by what method, what is still
unverified, and the open licensing question on the 99 Names' English
meanings.

## Contributing

Issues and pull requests are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, conventions, and what a good
PR looks like here, and [`ARCHITECTURE.md`](ARCHITECTURE.md) for the shape of
the codebase before your first change.

## License

The application source is [MIT licensed](LICENSE). Bundled reference content
carries its own sourcing and licensing notes — see
[`ThawabForGod/Resources/Corpus/README.md`](ThawabForGod/Resources/Corpus/README.md).
