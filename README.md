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
- **Quick actions and deep links** — long-press the app icon (or use the Dock
  menu on macOS) to jump straight to prayer times, Qibla, the adhkar or the
  Mushaf. Every destination is also a `noor://` URL.
- **Widgets** — the next prayer and a live countdown, on the iPhone and iPad
  Home Screen, the Lock Screen, and the Mac desktop. Computed in the widget's
  own process from the same engine the app uses, so it works with no network;
  with no stored location it says so rather than guessing a city.
- **Mac menu bar** — the next prayer and a live countdown in the status bar,
  with the day's schedule a click away. Optionally hides the Dock icon, and
  can start with your Mac.

**Phase 2 — built:**

- **The Quran** — a Library by surah, juz, hizb and page, and two ways to read:
  **Mushaf mode**, the Madina mushaf page by page as printed (604 pages), and
  **separated mode**, one ayah after another with translations under each.
  Tapping an ayah opens a panel with its translation and tafsir; there is
  search, bookmarks, notes and highlights, a remembered reading position, paper
  / sepia / dark reading themes, and on the Mac a Quran menu with keyboard
  paging. Two widgets (Continue Reading, Ayah of the Day), and layouts for
  iPhone Duo and other folds. The public build in this repository reads the
  Tanzil text in separated mode; the printed pages, fonts and translations are
  built from data that is not in the repository (see
  [Data & attribution](#data--attribution)).

**Phase 3 — partly built:** authentic hadith collections (Sahih al-Bukhari and
Sahih Muslim, Arabic, with search, bookmarks and spaced-repetition review) are
in. A `Memorize` mode across the adhkar, the 99 names, and short surahs is
planned.

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

| Domain | Source | License / status |
| --- | --- | --- |
| Prayer times & Qibla | [batoulapps/adhan-swift](https://github.com/batoulapps/adhan-swift) | MIT, on-device |
| Adhkar | Hisn al-Muslim transcription — see [`Corpus/README.md`](ThawabForGod/Resources/Corpus/README.md) | Unsettled, see notes |
| The 99 Names | Vendored & cross-checked from public data sets — see notes below | Unsettled, see notes |
| Quran text | [Tanzil Project](https://tanzil.net), Uthmani and Simple Clean, v1.1 — used verbatim | Creative Commons Attribution 3.0: source credited and linked, **no changes**; notice kept in the database |
| Tafsir al-Jalalayn (Arabic) | al-Mahalli and al-Suyuti (completed 1505), via the `spa5k/tafsir_api` mirror | Public domain by age |
| Quran font: KFGQPC HAFS Uthmanic Script v2.2 | King Fahd Glorious Quran Printing Complex | Its EULA: free to use, copy and distribute; not to be sold or modified — text in `Resources/Licenses/KFGQPC-EULA.txt` |
| Quran font: Amiri Quran | [aliftype/amiri](https://github.com/aliftype/amiri) | SIL OFL 1.1 — `Resources/Licenses/AmiriQuran-OFL.txt` |
| Interface font: IBM Plex Sans Arabic | [IBM/plex](https://github.com/IBM/plex) | SIL OFL 1.1 — `Resources/Licenses/IBMPlexSansArabic-OFL.txt` |
| Hadith (Bukhari, Muslim) | [fawazahmed0/hadith-api](https://github.com/fawazahmed0/hadith-api) | Unlicense on the mirror; the narrations are public domain by age — see the Corpus README |
| **QUL-derived Quran resources** | [Quranic Universal Library](https://qul.tarteel.ai): the KFGQPC V2 page layout and 604 page fonts, word-by-word text, surah header / name / juz faces, English surah introductions, Saheeh International, Tafsir al-Muyassar, Al-Mukhtasar (English) | **App Store build only; licence requested, not yet answered; not in this repository.** QUL publishes no licence. See [`docs/release/license-requests.md`](docs/release/license-requests.md) |

The repository builds and runs **without** the QUL-derived rows: a clone gets
the Tanzil build (separated mode, Jalalayn), and a Release build fails on
purpose until the full data is present. The raw QUL downloads and everything
built from them are git-ignored by name. The Quran text itself is never
altered — Tanzil's terms forbid it, and the build checks a SHA-256 over all the verses.

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
