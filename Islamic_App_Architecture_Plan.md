# Islamic App — Architecture & Product Plan

**Status:** living reference · **Platform:** native multiplatform (iPhone · iPad · macOS) · single SwiftUI codebase, Clean Architecture (MVVM‑C), Swift 6 strict concurrency · **Model:** open source, offline‑first, learning reference for native developers.

---

## 1. Vision & guiding principles

1. **Offline‑first, always.** Every core function works with the network off. Internet is an *enhancement* (city name, data updates, audio streaming), never a requirement for daily use.
2. **Native & multiplatform.** One SwiftUI codebase, adaptive layouts for phone/tablet/desktop. Structure so a watchOS "next prayer" complication and a visionOS build are later additions, not rewrites.
3. **Open source as a teaching artifact.** Clean, documented, well‑tested. The repo itself is a portfolio piece and a reference other native devs can learn from.
4. **Accuracy is a first‑class requirement.** Religious content is not "just data." Every dataset gets a verification pass against an authoritative source before shipping. Attribute sources; expose references in‑app.
5. **Ship in phases.** V1 is a complete, polished, publishable app. Quran/Hadith/Memorization are additive modules, not launch blockers.

---

## 2. Feature scope & phasing

**Phase 1 — Core (publishable V1)**
- Onboarding (description → location → notifications → calculation method)
- Home: prayer times for any selected date + next‑prayer countdown
- Prayer reminders (local notifications, rolling schedule)
- Qibla (compass + distance to Kaaba + coordinates)
- Adhkar (morning, evening, after prayer, meals, entering/leaving home)
- Tasbih (electronic counter, reusable per dhikr)
- 99 Names of Allah
- Hijri calendar + Islamic events
- Settings (theme color, number format AR/EN, language AR/EN, day/night, 12/24h)

**Phase 2 — Quran module**
- Full Quran (Uthmani script), verse‑by‑verse
- Per‑verse tafsir, with **multiple selectable tafsirs**
- Reading customization: font family, font size, background/paper color, line spacing
- Bookmarks, last‑read position, verse search
- (Optional) audio recitation + word highlighting

**Phase 3 — Hadith + Memorization**
- Authentic hadith collections with gradings and references
- Memorization mode (spaced repetition across adhkar, 99 Names, short surahs)

> **Rationale for phasing:** full Quran + multiple tafsirs + all authentic hadith + a memorization engine is several apps' worth of scope. Phasing lets you reach the App Store with a strong V1 and iterate publicly.

---

## 3. Onboarding feature

First‑run experience, built as a full feature module (`Features/Onboarding`) through all layers — the second vertical slice after Home. It gates the main interface on first launch, requests the two permissions the core features need, and seeds the initial `CalculationConfig` and language/theme defaults.

### 3.1 Screens, in order
1. **Welcome / description** — one or two panels: what the app is, offline promise, privacy note (location stays on device).
2. **Location permission** — explain *why* (prayer times + Qibla). Request `whenInUse`. If denied, allow manual city/coordinate entry so the app still works.
3. **Notification permission** — explain *why* (prayer reminders, optional adhkar reminders). Graceful if denied.
4. **Calculation method** — pick method (default by region) + Asr madhab (Shafi/Hanafi). Editable later in Settings.
5. **Done → main interface.**

### 3.2 Architecture
- **Domain:** `OnboardingStep` enum, `OnboardingState` entity, `CompleteOnboardingUseCase`, and a `OnboardingRepositoring` protocol (persists the completion flag + seeded config).
- **Data:** `OnboardingRepository` backed by SwiftData/`UserDefaults` for the flag; delegates permission requests to `LocationService` / `NotificationService` (Core).
- **Features/Onboarding:** `@Observable` `OnboardingViewModel` driving a step machine, `OnboardingCoordinator` for navigation, one SwiftUI view per step composed under a container view. Keep each step `body` small.
- **Routing:** `AppContainer` / root coordinator decides at launch — read the completion flag and route to `OnboardingCoordinator` or the main interface.

### 3.3 Design notes
Keep it skippable where reasonable, persist a "completed onboarding" flag, and never hard‑block the app if a permission is denied — degrade gracefully. Mirror every screen for RTL and localize all strings (AR/EN) from day one. Route digits through `NumberFormattingService`.

---

## 3a. Contextual guidance — TipKit

Use Apple's **TipKit** (iOS 17+, iPadOS 17+, macOS 14+) for lightweight, contextual, *post‑onboarding* education — not as a substitute for onboarding. Onboarding sets the app up; TipKit surfaces one‑off tips at the moment a feature first becomes relevant (e.g. "Tap and hold the counter to reset" on Tasbih, "Pull to change the date" on Home, "Long‑press a dhikr to start memorizing").

### 3a.1 Why TipKit
- **Rules‑based display + frequency control** — show a tip only when eligible (e.g. after N launches, feature unused, a related event fired), and never nag: TipKit handles per‑tip display counts and dismissal persistence for you.
- **Cross‑platform + native** — same `Tip` definitions render as popovers/inline views across iPhone, iPad, and macOS; no custom coach‑mark engine to maintain.
- **iCloud sync** of tip status across a user's devices, so a dismissed tip stays dismissed.

### 3a.2 Architecture fit
- Add a **`TipsService`** to Core: configures the tip store at launch (`Tips.configure`), owns `Tips.Configuration` (display frequency, datastore location), and exposes helpers to reset/invalidate tips (useful for testing and a "reset tips" Settings action).
- Define `Tip` values **per feature**, colocated in each `Features/<Feature>` folder, so a feature owns its own tips. Keep them free of business logic — they read `@Parameter` event/state flags, not Domain use cases directly.
- Drive eligibility with TipKit **events and parameters** fed from ViewModels/services (e.g. increment a "prayerScreenOpened" event), keeping the Domain layer clean of any TipKit import.
- Localize every tip title/message (AR/EN) via String Catalogs; verify RTL rendering of popovers.

### 3a.3 Scope
Introduce TipKit **after** the first two vertical slices (Home, Onboarding) are proven, then add tips incrementally as each feature ships. It is cross‑cutting infra plus per‑feature content, so it slots in as a Core service without blocking feature work.

---

## 4. Offline‑first data & sync architecture

### 4.1 Prayer times — computed locally, no API needed
Use the **Adhan** Swift library (MIT, zero dependencies, Swift‑6 clean, iOS/macOS/visionOS/watchOS). Inputs: coordinates + date + `CalculationParameters` (method + madhab). It returns all five times, sunrise, next‑prayer, and can compute Qibla direction and Sunnah times (last third of night, etc.).

Consequences:
- **No internet is ever required for prayer times.** Compute any date on demand.
- The "save the whole current year" requirement is unnecessary — there is nothing to cache; you compute instantly for any date. (If you still want a materialized year for a calendar view, precompute and store it locally in one pass.)
- **Qibla** comes from the same library — one engine powers two features.

Repo: `https://github.com/batoulapps/adhan-swift` · SPI: `https://swiftpackageindex.com/batoulapps/adhan-swift`

### 4.2 Location
- **Coordinates** come from CoreLocation via GPS — this works **offline**.
- **City/place name** requires reverse geocoding (network). Treat the name as cosmetic; never block on it.
- Allow manual location entry as a fallback (denied permission, or user travelling).

### 4.3 Optional API sync (not load‑bearing)
Keep the **AlAdhan API** only as an optional verification/refresh source. It's free, no auth, and its `calendar` endpoint returns a full month or year in one request; it also does Hijri conversion and Qibla. Use it, if at all, for cross‑checking local computations or future server features — not as a dependency.
- API: `https://aladhan.com/prayer-times-api` · Methods: `https://aladhan.com/calculation-methods`

### 4.4 Background refresh on launch (your model, refined)
On app start / foreground, **if** the network is available:
1. Refresh location if it changed materially.
2. Recompute today's times (local — instant), update the city label.
3. Reschedule the rolling notification window.
4. (Phase 2+) Check for corpus data updates (new/edited tafsir, translations).

If offline: everything above except steps needing the network is still done from local data.

### 4.5 Notifications — mind the iOS cap
iOS allows a **maximum of 64 pending local notifications**. Do **not** schedule a year of prayers. Instead:
- Schedule a **rolling window** (e.g. next ~10 days × 5 prayers ≈ 50 notifications).
- Re‑fill the window on every launch/foreground and via background app refresh.
- Optionally register notification categories for "snooze"/"mark prayed".

### 4.6 Corpus data (Quran, tafsir, hadith, adhkar, 99 Names)
These are large, static, read‑only texts.
- **Ship a prebuilt SQLite database** in the bundle for the essentials (Quran Arabic, one default translation, adhkar, 99 Names) so the app is fully usable on first launch offline.
- **Download‑on‑demand modules** for optional heavy content (extra tafsirs, extra translations, audio) to keep initial app size down. Cache to Application Support; make them removable.
- Query via **GRDB** (fast, Swift‑native SQLite) behind a repository protocol.

### 4.7 Storage split
| Data | Nature | Store | Access |
|---|---|---|---|
| Quran, tafsir, hadith, adhkar, 99 Names | Read‑only corpus | Bundled/downloaded **SQLite** | GRDB, via repositories |
| Bookmarks, last‑read, memorization progress, tasbih counts, settings | Mutable user data | **SwiftData** (or Core Data) | via repositories |
| Computed prayer times, cached year (optional) | Derived | In‑memory / lightweight cache | recompute cheaply |

Keep both behind **repository protocols** in the Domain layer so the storage tech is swappable and testable.

---

## 5. App architecture

Layered Clean Architecture, feature‑first folders, MVVM‑C. This mirrors the proven layering in the open‑source Quran.com iOS app (`quran/quran-ios` / *QuranEngine*), which is worth studying directly.

```
App/            Composition root, AppContainer (manual DI), app entry, routing
Core/           Cross‑cutting infra: networking, persistence, DI, formatters,
                location, notifications, theming, localization, logging
Domain/         Pure Swift. Entities + Use Cases + Repository PROTOCOLS.
                No SwiftUI / UIKit imports. Fully unit‑testable.
Data/           Repository IMPLEMENTATIONS, data sources (SQLite/GRDB,
                SwiftData, network), DTOs + mappers.
Features/       One folder per feature: Views (SwiftUI) + ViewModels +
                Coordinator. Composes Domain use cases.
Resources/      Assets, localized strings (AR/EN), bundled DB, fonts.
```

**Dependency rule:** Features → Domain ← Data. Domain depends on nothing UI‑ or framework‑specific. Data and Features depend on Domain abstractions, wired at the composition root.

### 5.1 Feature modules
`Onboarding` · `Home/PrayerTimes` · `Qibla` · `Adhkar` · `Tasbih` · `NamesOfAllah` · `HijriCalendar` · `Settings` · (P2) `Quran` · (P3) `Hadith` · `Memorize`

### 5.2 Cross‑cutting services (Core)
- **PrayerTimeEngine** — wraps Adhan; single source of truth for times + Qibla bearing.
- **LocationService** — CoreLocation, permission handling, manual‑entry fallback.
- **NotificationService** — schedules the rolling window; reschedules on settings/location change.
- **HijriDateService** — Gregorian↔Hijri (Umm al‑Qura), event lookup.
- **ThemeService** — accent color, day/night, follows or overrides system.
- **LocalizationService** — AR/EN, **RTL mirroring**, locale.
- **NumberFormattingService** — Arabic‑Indic vs Latin digits, applied app‑wide.
- **TipsService** — configures TipKit at launch; owns tip datastore + display frequency; reset/invalidate helpers. Per‑feature `Tip` values live in each feature folder.
- **AudioService** (P2) — recitation playback, per‑ayah timestamps.

### 5.3 Modularization (deferred, per prior decision)
Keep layers as folder groups with import discipline first. Once one vertical slice is proven, extract stable layers (Domain, Core, a design‑system package) into **Swift Package Manager** modules. QuranEngine is a good example of a fully SPM‑modularized target graph to model this on later.

---

## 6. Open data sources

> **License caveat:** verify each dataset's license before shipping, especially if you monetize. Several mirrors carry non‑commercial (CC BY‑NC) terms even when the underlying text is public. Prefer MIT/Apache/CC0 sources or obtain permission. Always attribute.

| Domain | Source | Notes |
|---|---|---|
| Prayer times + Qibla | `batoulapps/adhan-swift` | **MIT.** On‑device compute. Primary engine. |
| Prayer/Hijri/Qibla API (optional) | AlAdhan — `aladhan.com`, `github.com/islamic-network` | Free, no auth; yearly calendar; open source. |
| Quran + translations + tafsir + audio + Mushaf layout | **Quranic Universal Library** — `qul.tarteel.ai` | Curated hub; JSON/SQLite; word‑by‑word, scripts, fonts. Best sourcing point. |
| Quran translations (CDN) | `fawazahmed0/quran-api` | 400+ translations via jsDelivr; check license. |
| Tafsir (CDN) | `spa5k/tafsir_api` | 122 tafsirs; no rate limits; check license. |
| Quran + tafsir API | Quran.com / Quran Foundation — `api-docs.quran.foundation` | Official API v4; needs app credentials. |
| Quran text/audio API | `api.alquran.cloud` | Free, no auth; text + tafsir + audio editions. |
| Hadith (structured) | `AhmedBaset/hadith-json` | ~50,884 hadith, 9 books + Riyad as‑Salihin + Nawawi 40; by book/chapter; gradings. |
| Hadith (CDN, multi‑grade) | `fawazahmed0/hadith-api` | Multiple languages + grades; **verify license (some mirrors are CC BY‑NC).** |
| Adhkar (Hisn al‑Muslim) | `Seen-Arabic/Morning-And-Evening-Adhkar-DB` | **MIT.** AR/EN; JSON/CSV/SQL/SQLite. |
| Adhkar (JSON) | `ahegazy/muslimKit`, `wafaaelmaandy/Hisn-Muslim-Json` | AR/EN azkar JSON. |
| All‑in‑one (times, geocoder, azkar, 99 names) | "Muslim Data" (via `choubari/Awesome-Muslims`) | Convenient offline bundle to reference. |
| Curated resource lists | `tarekeldeeb/awesome-islamic-open-source-apps`, `choubari/Awesome-Muslims`, `khDev01/islamic-data` | Discovery + learning. |

**Reference apps to study (native, open source):**
- **`quran/quran-ios` (QuranEngine)** — Apache‑2.0, Swift, actively maintained. Closest match to your Clean Architecture. **Primary reference.**
- `omodyspireon/Quran-Pro-iOS` — Swift 5 Quran app (older patterns, but full‑featured incl. memorization audio repeat).

---

## 7. Memorization — method + feature design

You asked for a *practical* method for memorizing prayer times, supplications, and remembrances. This has two parts: the pedagogy, and how to build it into the app.

### 7.1 The method (evidence‑based)
1. **Active recall + spaced repetition** is the core. Reviewing *from memory* at increasing intervals beats re‑reading. Implement **SM‑2** or **Leitner boxes**.
2. **Chunk** each dhikr/verse into short phrases; memorize phrase‑by‑phrase, then join.
3. **Listen → repeat aloud → recall** loop: hear correct pronunciation, repeat, then recall with the text hidden.
4. **Progressive masking:** full text → hide translation (recall Arabic) → hide words progressively → recall whole.
5. **Meaning first.** Understanding the translation dramatically improves retention.
6. **Tie to routine.** Attach adhkar practice to prayer notifications; recite short surahs inside salah. Consistency (5–10 min daily) beats cramming.
7. **Prayer *times* are routine, not rote.** "Memorizing" times = building awareness. The real levers are reliable notifications, a glanceable next‑prayer widget, and (optionally) a light quiz on prayer order and relative timing.

### 7.2 The feature
A single **Memorize** mode spanning adhkar, 99 Names, and short surahs:
- Per‑item **SR scheduler** (SM‑2/Leitner) with a daily **due queue**.
- **Recall / flashcard UI** with progressive masking and self‑grading (again / hard / good / easy).
- **Audio** repeat controls (single item ×N, loop).
- **Progress + streaks**, gentle daily reminder (respecting notification budget).
- Progress stored in SwiftData (user data), independent of the read‑only corpus.

---

## 8. Reading experience (Phase 2)
For the Quran reader, expose:
- **Font**: family (incl. proper Uthmani/Arabic faces) + size.
- **Background/paper color**: light, sepia/parchment, dark, high‑contrast — for eye comfort.
- **Line spacing** and margins.
- **Tafsir picker**: choose and switch between multiple tafsirs per verse.
- **Bookmarks + last‑read** restore.
- Respect the app's global day/night and accent settings, but allow reader‑specific overrides.

QUL provides Mushaf‑layout data so you can render pages like the printed Mushaf later — good for hifz familiarity.

---

## 9. Multiplatform notes
- Adaptive SwiftUI layouts: `NavigationSplitView` for iPad/macOS, `NavigationStack`/tabs for iPhone. **Done.** `MainInterfaceView` branches on `horizontalSizeClass`; `AppTab.visible` is the one list both arrangements read, and `AppSectionView` is the content both show. Two columns, not three — see `CLAUDE.md` for why.
- macOS: window sizing, menu commands, keyboard support; CoreLocation prompts differ. **Mostly done** — `defaultSize`/`windowResizability` on the `WindowGroup`, ⌘1…⌘4 for the sections. iPad hardware-keyboard shortcuts are not wired yet.
- Later: watchOS "next prayer" complication; visionOS build. Adhan already supports both platforms.
- RTL: build every screen to mirror cleanly for Arabic from day one.

---

## 9a. Beyond the app window — quick actions, widgets, menu bar

Everything above assumes the reader opens the app. These three do not: a long press on the icon, a glance at the Home Screen or the Lock Screen, a countdown in the Mac's menu bar. They are one piece of work rather than three because they share a prerequisite — a way in from outside the process — and, on Apple's platforms, that is a URL.

> **Why now.** `CLAUDE.md` has claimed since the tab bar landed that navigation state lives outside the view tree so that "a deep link (a tapped reminder, a widget) can move between sections without reaching into the view hierarchy". Nothing had ever tested that claim. These slices do.

### 9a.1 Deep links and quick actions — **Done.**

`DeepLink` is the app's external vocabulary: nine destinations, one `noor://` scheme, a total round trip between the two. Deliberately **not** `AppRoute` — `AppRoute` carries feature-Domain payloads a second process cannot see, and more importantly the two have different lifetimes. A route is internal wiring and may be reshaped freely; a link is a *promise*, because iOS caches shortcut items and widget URLs across builds. `AppContainer.open(_ link:)` is the single place the promise is reconciled with whatever the app's internals happen to look like today.

`AppQuickAction` is the list on the icon, shaped exactly like `HomeShortcut`: declaration order is display order, `isAvailable` is the one switch that removes an entry, and `visible` caps at the four iOS will show rather than letting the system drop the tail silently. macOS reads the same list into its Dock menu.

Delivery is asymmetric, and that is why there is an `AppDelegate` at all. A widget tap is a URL and SwiftUI hands it to `.onOpenURL`. A quick action is a `UIApplicationShortcutItem` delivered to a `UIWindowSceneDelegate`, which a SwiftUI app does not have unless it asks — and on a cold launch it arrives before `RootView` has a body. Hence `DeepLinkInbox`: the delegate posts, the view consumes when it is ready.

### 9a.2 The shared target

A widget runs in its own process and can share nothing with the app by default. Three things have to change: a folder of source compiled into both targets, an **App Group** so `UserDefaults` is visible from both, and the localized strings and colour assets in both bundles.

The folder is `Shared/` — prayer times, settings, localization, theming, the clock — chosen by one rule: *a subsystem belongs there when a second process needs it and it costs no heavy dependency to take.* Everything with SwiftData, GRDB or a corpus file behind it stays in `Core/`, which keeps the widget inside WidgetKit's memory budget and its link line down to Adhan.

### 9a.3 Widgets

Next prayer and countdown, small and medium on the Home Screen, the accessory families on the Lock Screen, and the same extension on the Mac desktop. The compute path needs no new code: `GetPrayerScheduleUseCase` is already `nonisolated`, synchronous and Foundation-plus-Adhan only.

Two decisions worth recording. The timeline holds **one entry per prayer transition**, not one per minute — the countdown is a system-rendered timer text that animates without waking the extension. And a widget with **no stored coordinates says so** rather than falling back to Makkah: that is §4.5's reminder rule ("no coordinates, no reminders"), and it binds harder here, because a wrong time on the Home Screen is wrong all day with nobody looking at it.

### 9a.4 The Mac menu bar

An `NSStatusItem` carrying the next prayer and a live countdown, and an `NSPopover` with the day's schedule on click — the Mac idiom for exactly what the Home Screen widget does, and the reason it is AppKit rather than `MenuBarExtra` is that the *label* has to redraw on a ticker.

Launch at login is `SMAppService.mainApp`, behind a protocol so Domain never imports ServiceManagement. The state that matters is `requiresApproval`: macOS has recorded the request and the user must confirm it in System Settings → General → Login Items. A toggle that silently snaps back is the failure that state exists to prevent, so the row says so and offers the button that opens the page.

---

## 10. Open‑source & repo strategy
- **License:** MIT or Apache‑2.0 (maximizes reuse and learning). Match the license of any bundled data.
- **Repo hygiene:** clear README (architecture diagram, setup, data‑attribution), `CONTRIBUTING.md`, `LICENSE`, `ARCHITECTURE.md`, tests, CI. **CI is Xcode Cloud, not GitHub Actions** — the repo side is done (shared scheme, pinned `Package.resolved`) and the workflow itself has to be created once in App Store Connect by a Developer Program member. Reasoning and the exact workflow to create are in `CI.md`.
- **Learning framing:** annotate the code and docs so the architecture is legible to newcomers — this is part of the product's purpose and strengthens your portfolio.
- **Attribution page** in‑app crediting every data source.

---

## 11. Accuracy & responsibility
- Treat every religious dataset as **unverified until checked**. The dataset authors themselves note content is not guaranteed 100% accurate.
- Before shipping any corpus (Quran text, tafsir, hadith gradings, adhkar): run a verification pass against an authoritative source (e.g. Tanzil/King Saud University for Quran text; recognized collections and gradings for hadith).
- Show **references** in‑app (surah:ayah, hadith collection + number + grade, adhkar source book) so users can verify.
- Prefer well‑established sources; document exactly which edition/source each item came from.

---

## 12. Suggested build order
1. Finalize designs for V1 screens (in progress).
2. Wire **PrayerTimeEngine** (Adhan) + **LocationService** → Home vertical slice (real times, offline).
3. **Onboarding** vertical slice → welcome, location + notification permissions, calculation method; launch routing on the completion flag, seed initial config.
4. **TipsService** (TipKit) → configure at launch; add first contextual tips to Home + Onboarding, then per feature as they ship.
5. **HijriDateService** → Hijri date on Home + calendar.
6. **NotificationService** (rolling window) + prayer reminders.
7. Qibla (reuse the engine).
8. Adhkar (bundled SQLite) → then Tasbih → 99 Names.
9. Settings (theme, digits, language/RTL, day‑night, 12/24h, reset tips).
10. Polish, tests, CI → **publish V1**. *In progress. The adaptive layout is done and the CI prerequisites are committed; the one remaining hard blocker is the corpus verification pass required by §11 — the adhkar text and the English meanings of the 99 Names are still unverified, and `Resources/Corpus/README.md` holds the standing warnings.*
11. Phase 2: Quran + tafsir module.
12. Phase 3: Hadith + Memorization.
13. Beyond the app window (§9a): deep links + quick actions, widgets, the Mac menu bar. *In progress. Deep links and quick actions are done; the widget and the menu bar are next, and both wait on the `Shared/` folder and the App Group described in §9a.2.*

**Built beyond this plan:** two slices that were not in the original scope and belong in it now — `Core/PrayerTracker` (marking the day's prayers off, with a streak) and `Core/Activity` (recent items), plus a Home screen the reader arranges themselves. Steps 2–9 are otherwise complete, and Phases 2 and 3 both landed ahead of step 10.

**Next step:** the corpus verification pass (§11) remains the last hard blocker on a publishable V1, and it is a reviewing job rather than a coding one. Running alongside it: §9a, which is the first work in this project to put anything outside the app's own window. After both: the `Memorize` mode spanning adhkar, the 99 Names and short surahs (§7.2), which `Core/Memorization` was already factored for; the hadith deck is the only one built so far.

---

*Sources: batoulapps/adhan-swift; aladhan.com; qul.tarteel.ai; api-docs.quran.foundation; fawazahmed0/quran-api; spa5k/tafsir_api; api.alquran.cloud; AhmedBaset/hadith-json; fawazahmed0/hadith-api; Seen-Arabic/Morning-And-Evening-Adhkar-DB; quran/quran-ios (QuranEngine); awesome-islamic-open-source-apps; choubari/Awesome-Muslims.*
