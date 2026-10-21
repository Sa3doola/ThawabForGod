# Prompt: Islamic (Hijri) Calendar + Moon Phase feature

Copy everything below the line into Claude Code, run from the Noor Xcode project root (where `CLAUDE.md` lives). Self-contained: no attachment needed.

---

You are building the **Islamic Calendar feature** for Noor: a Hijri month calendar, a full list of Islamic occasions, a moon-phase engine with a visual explanation, and a Home integration.

Read `CLAUDE.md` first and follow every convention: Clean Architecture / MVVM-C, Swift 6 strict concurrency, `@Observable` (never `ObservableObject`), constructor injection wired only at `AppContainer`, protocol in Domain per service/repository, String Catalogs (AR/EN), RTL-first layouts, digits through `NumberFormattingService`, no `AnyView`, no hand-editing `project.pbxproj`. Use `AppFont` tokens if the fonts work has landed.

## 0. Git: work on a new branch

Before touching any file:

1. Run `git status`. If the working tree has uncommitted changes, stop and tell me. Don't stash or discard anything.
2. Note the current branch, then create and switch to a new branch from it: `git switch -c feature/hijri-calendar-moon`. If that name already exists, add a short suffix instead of reusing it.
3. Make all changes on that branch only. Never commit to `main`/`master`, never force-push, never rewrite history.
4. Commit once per slice (§9) with a clear message like `feat(calendar): moon phase engine + tests`, and only after that slice builds clean and its tests pass.
5. Don't push, open a PR, or merge unless I ask. At the end, print the branch name, the base branch, and `git log --oneline` for the new commits.

**This extends existing code.** Before writing anything, read `Features/Home`, `HijriDateService`, `NumberFormattingService`, `ThemeService`, `PrayerTimeEngine`, and `Features/Settings` (for the Hijri day offset). Reuse them. If something here conflicts with the codebase, stop and ask.

## 1. Target screens (from the design screenshot)

**`HijriCalendarView`** (pushed from Home / More; back chevron on the leading side), top to bottom:

1. **Header:** large Hijri date for the *selected* day ("١٠ جمادى الأولى ١٤٤٨ هـ") in accent color, Gregorian date beneath it in secondary text.
2. **Moon card** for the selected day (dark navy gradient card, see §3): label "القمر الليلة", phase name large, "مضيء ٧٩٪ · ٣٩١٬٧٠٠ كم", a drawn moon on the trailing side, and a pill button to open the moon detail screen.
3. **Month calendar card** (see §2).
4. **"المناسبات القادمة"** section: hint line "اضغط على أي مناسبة لتعرف فضلها وما يُستحب فيها", then occasion rows (§4).

## 2. Month calendar

- Month title in the card header ("جمادى الأولى ١٤٤٨"), with previous/next buttons and a "اليوم" (Today) button that appears only when the shown month is not the current one. Tapping the title opens a month/year picker.
- **Looks like the native Apple Calendar month grid:** weekday header row, 7 columns, week rows, equal cell size, today = filled rounded highlight (as in the screenshot), selected day = outlined highlight, small dot under days that have occasions. Don't build a list; use a `LazyVGrid` of 7 flexible columns.
- **Swipe between months** with horizontal paging (`ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` / `scrollPosition`, iOS 17). Paging direction must mirror in RTL. Prev/next buttons do the same thing with animation.
- **Gregorian-date-per-day option:** a toggle ("إظهار التاريخ الميلادي") that renders the Gregorian day number as a small secondary label under each Hijri number. Persist it in Settings → Language & format (`showGregorianInCalendar`, default off). When on, also show the Gregorian month span in the card header (e.g. "أكتوبر – نوفمبر ٢٠٢٦").
- Week start follows the user's locale, with a Settings override (Saturday / Sunday / Monday). The screenshot uses Saturday-first for Arabic.
- Hijri months have 29 or 30 days: get the length from `Calendar(identifier: .islamicUmmAlQura).range(of: .day, in: .month, for:)`, never hardcode. Leading blanks come from the weekday of day 1.
- Supported range: clamp to a sane window (e.g. 1318–1500 AH, what Umm al-Qura covers) and disable navigation at the ends.
- **Apply the user's Hijri day offset** (Settings, −2…+2) everywhere dates are produced, through the existing `HijriDateService`. Don't add a second path.
- Tapping a day selects it; the header, moon card, and a day-detail sheet update (Gregorian date, Hijri date, occasions that day, moon info). Selection state lives in the ViewModel.
- Numbers (day numbers, years) go through `NumberFormattingService`.

## 3. Moon phase engine

**Why the moon matters here:** a Hijri month begins with the new crescent. Explain this honestly in the UI. The moon info *explains* the date, but Umm al-Qura is a calculated calendar and local sighting can differ by a day. That is why the Hijri offset setting exists. Don't claim the app derives the Hijri date from the phase.

### 3.1 Architecture

- Domain: `MoonPhaseCalculating` protocol and entities `MoonPhase` (enum, 8 cases), `MoonInfo`.
- Implementation `AstronomicalMoonCalculator` in `Core`, pure Swift, no network, injected through `AppContainer`.
- Use cases: `GetMoonInfoUseCase(date:)`, `GetMoonPhaseStripUseCase(forHijriMonth:)`, `GetNextMoonEventsUseCase`.

```swift
public struct MoonInfo: Equatable, Sendable {
    public let date: Date
    public let phase: MoonPhase
    public let illuminatedFraction: Double   // 0...1
    public let elongationDegrees: Double     // 0..<360, 0 = new, 180 = full
    public let isWaxing: Bool
    public let ageInDays: Double             // since last new moon
    public let distanceKm: Double
}
public enum MoonPhase: CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous,
         fullMoon, waningGibbous, lastQuarter, waningCrescent
}
```

### 3.2 Algorithm (Jean Meeus, *Astronomical Algorithms*, ch. 47–48, low-precision form)

Verify the constants against the book or a reputable reference. Don't trust them blindly, and flag anything you can't confirm.

- Julian Day from `Date` (JD = unix/86400 + 2440587.5). `T = (JD − 2451545) / 36525`.
- Mean elongation `D = 297.8501921 + 445267.1114034 T − 0.0018819 T² + T³/545868`
- Sun's mean anomaly `M = 357.5291092 + 35999.0502909 T − 0.0001536 T²`
- Moon's mean anomaly `M′ = 134.9633964 + 477198.8675055 T + 0.0087414 T² + T³/69699`
- Moon's argument of latitude `F = 93.2720950 + 483202.0175233 T`
- Phase angle (degrees): `i = 180 − D − 6.289 sin M′ + 2.100 sin M − 1.274 sin(2D − M′) − 0.658 sin 2D − 0.214 sin 2M′ − 0.110 sin D`
- Illuminated fraction `k = (1 + cos i) / 2`
- Waxing if `D mod 360 < 180`
- Distance (km): `385000.56` plus the principal periodic terms of ch. 47 Table 47.A (the Σr column, units of 0.001 km). The largest are `−20905.355 cos M′`, `−3699.111 cos(2D−M′)`, `−2955.968 cos 2D`, `−569.925 cos 2M′`, `+246.158 cos(2D−2M′)`, `−204.586 cos(2D−M)`, `−170.733 cos(2D+M′)`, `−152.138 cos(2D−M−M′)`, `−129.620 cos(M−M′)`, `+108.743 cos D`, `+104.755 cos(M+M′)`, `+48.888 cos M`. Ignoring the small eccentricity factor E on the M terms is acceptable (error is tens of km, which is fine for display; round to the nearest hundred).
- Phase name from elongation in 45° wedges centered on 0°, 45°, 90°, … (new, waxing crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter, waning crescent).
- **Age** = days since the last new moon. Find it by scanning backwards (hourly steps, max ~30 days) for the elongation wrapping through 0°, then bisect to the minute. The same search forward gives next new moon and next full moon (elongation 180°).
- **Evaluation time for a calendar day:** use that day's Maghrib from `PrayerTimeEngine` ("the moon tonight", which is also when the crescent is looked for). Fall back to 18:00 local if prayer times are unavailable. For "right now" in the Home card, use the current time.
- Hemisphere: the lit side flips between hemispheres. Orient the drawing using the sign of the user's latitude (default northern if unknown). Keep this in the drawing layer, not the calculator.

### 3.3 Tests (XCTest, in `Domain`/`Core` test targets)

- Known events within ±1 hour (look the values up on USNO or timeanddate, don't guess them): new moon on 2026-10-10 (UTC) and full moon on 2026-10-26 (UTC).
- On 2026-10-21 the app currently displays about 79% illuminated, waxing gibbous, about 391,700 km. Assert 0.77…0.81 and 389,000…394,500 km.
- Distance always lies between 356,000 and 407,000 km across a 2-year sweep. Illumination stays in 0…1. `isWaxing` flips exactly at full and new moon.
- Age is monotonic within a cycle and always within 0…29.9.
- Phase naming at the wedge boundaries.

### 3.4 Drawing the moon: `Features/Calendar/Views/MoonView.swift`

Draw it with SwiftUI `Path`/`Canvas`, not image assets, so every phase and size is exact:

- Dark disc as the base, the lit region on top. The lit shape is a half-disc on the lit side plus an ellipse for the terminator with horizontal radius `r · |cos(i)|`, added or subtracted depending on whether it's a crescent or gibbous.
- A soft glow, plus subtle crater texture (a few translucent circles, or a masked bundled texture if you have one with a clear license).
- Inputs: `illuminatedFraction`, `isWaxing`, `hemisphere`. Mirror correctly in RTL. The moon's physical orientation does **not** flip with layout direction, so don't let SwiftUI's RTL mirroring flip it.
- Accessibility label: "Waxing gibbous, 79 percent illuminated" (localized).

## 4. Occasions

**The app already ships `IslamicEvents.json`. Use it as the source of truth. Do not create a second occasions file.**

Its current shape (10 events, a flat array of single fixed Hijri dates):

```json
{ "id": "mawlid", "nameKey": "event_mawlid", "noteKey": "event_note_observance_varies", "month": 3, "day": 12 }
```

Fields: `id`, `nameKey` (String Catalog key), optional `noteKey` (String Catalog key), `month` (1–12), `day`. Existing ids: `islamic_new_year`, `ashura`, `mawlid`, `isra_miraj`, `nisf_shaban`, `ramadan_start`, `laylat_al_qadr` (27 Ramadan only), `eid_al_fitr`, `arafah`, `eid_al_adha`. Existing note keys: `event_note_observance_varies`, `event_note_moon_sighting`, `event_note_last_ten_nights`.

Rules:

1. Find the file and whatever already loads it (`Glob **/IslamicEvents.json`, then grep for `IslamicEvents` and `nameKey`). Reuse that loader and its types if they exist, and wrap them in the repository below.
2. **Do not change existing ids, keys, months, or days.** Existing entries keep working exactly as they do today; a missing `rule` means `fixedDay(month, day)`.
3. Extend the schema only with **optional** fields so current decoding keeps working: `category`, `rule` (overrides month/day for multi-day and recurring events), `summaryKey`, `virtueKey`, `sources`, `scholarlyNoteKey`. All text stays localization-key based: add the keys to the String Catalog (AR + EN), never inline strings in the JSON. Existing `noteKey` stays as is and is shown in the detail sheet.
4. Add only the missing events from the target set below, using the same `event_*` key naming. Where an existing entry is a narrower version of a target (for example `ashura` is only 10 Muharram; `laylat_al_qadr` is only 27 Ramadan), keep the entry and add the wider coverage as a `rule` on it or as a new entry. Tell me which you chose.
5. `category` defaults by id for existing entries (set in the loader or JSON): eid → `eid_al_fitr`, `eid_al_adha`; fasting → `ashura`, `arafah`; night → `isra_miraj`, `nisf_shaban`, `laylat_al_qadr`; season → `ramadan_start`, `islamic_new_year`; `mawlid` → `historical`. Confirm or adjust.
6. Read it through `IslamicOccasionsRepositoring` (Domain) + `BundledOccasionsRepository` (Data).

```swift
public enum OccasionRule: Codable, Sendable {
    case fixedDay(month: Int, day: Int)
    case dayRange(month: Int, from: Int, to: Int)
    case monthlyDays([Int])               // e.g. white days 13,14,15
    case weekly(weekdays: [Int])          // Mon/Thu fasting
    case oddNights(month: Int, days: [Int]) // last ten nights of Ramadan
}
public enum OccasionCategory: String, Codable, Sendable { case eid, fasting, night, season, historical }
```

Domain record: `id`, `nameKey`, `category`, `rule`, optional `noteKey`, `summaryKey`, `virtueKey` (nullable), `sources` (array of `{ work, reference, grading? }`), `scholarlyNoteKey` (nullable).

Target set (merge with what `IslamicEvents.json` already has, no duplicates):

- 1 Muharram (Hijri new year); 9–10 Muharram (Tasu'a & Ashura, fasting)
- 12 Rabi' al-Awwal (Mawlid: flag a `scholarlyNote` that scholars differ on its observance)
- 27 Rajab (Isra and Mi'raj: note the difference of opinion on the date)
- 15 Sha'ban (mid-Sha'ban: neutral wording, with a note on the differing scholarly views)
- 1 Ramadan; last ten nights and odd nights (21, 23, 25, 27, 29) for Laylat al-Qadr
- 1 Shawwal (Eid al-Fitr); six days of Shawwal
- 1–9 Dhul Hijjah (first ten days); 9 Dhul Hijjah (Day of Arafah); 10 Dhul Hijjah (Eid al-Adha); 11–13 Dhul Hijjah (Days of Tashreeq)
- Recurring: Ayyam al-Bid (13, 14, 15 of every month), Monday and Thursday fasting
- Historical (category `historical`, can be hidden): 17 Ramadan (Badr), 20 Ramadan (Conquest of Makkah)

**Accuracy rules (Architecture Plan §11), non-negotiable:**

- Don't invent hadith, virtues, or rulings. Every `virtue` or ruling text must carry a source and grading. If you can't confirm a source from a recognized collection, leave `virtue` null and add `// TODO(verify)` in the build notes. Do not fabricate to fill the UI.
- Where there is scholarly difference, say so in `scholarlyNote`.
- List every record's missing/unverified items in your final summary so I can verify them.

**Resolution:** `ResolveOccasionDatesUseCase(hijriYear:)` converts rules to concrete `(hijriDate, gregorianDate)` pairs using the Umm al-Qura calendar and the Hijri offset. Cache per year. Add `GetUpcomingOccasionsUseCase(from:limit:)` that wraps into the next Hijri year when needed.

**UI:**

- "المناسبات القادمة" rows: title, Hijri date, Gregorian date, "بعد N يوم" (days-away), and a category tint. Tapping opens an `OccasionDetailSheet` with summary, virtue, sources, and the scholarly note.
- A "كل مناسبات السنة" link opens `OccasionsYearView`: all occasions grouped by Hijri month for the chosen Hijri year, with a year stepper.
- Day cells show a dot when the day has ≥1 occasion. Recurring ones (white days, Mon/Thu) get a quieter dot style so they don't drown the grid. Settings gets a toggle to hide recurring-fasting dots.

## 5. Moon detail screen: `MoonDetailView`

Opened from the pill button. Use a good, clean interface:

- A large moon for the selected day, with phase name, illuminated %, age ("عمر القمر ٩ أيام"), and distance.
- An **8-phase strip** for the lunar month with the selected day marked, and tapping a phase jumps to the next day it occurs.
- Next new moon and next full moon (date + countdown), computed locally.
- A short, plain-language explainer card: "كيف يبدأ الشهر الهجري؟" (the month starts with the sighting of the new crescent after the conjunction; Umm al-Qura is calculation-based, so a local sighting can differ by a day; use the Hijri offset in Settings to match your community). Localize AR/EN. Keep it to 3–4 sentences.
- **Optional, last slice only:** a "3D moon" pill/screen (a SceneKit/RealityKit sphere with a lit-by-sun-direction texture) like the screenshot's "استكشف القمر ثلاثي الأبعاد". Only do it if there is a properly licensed moon texture (NASA imagery is public domain; confirm and attribute). If not available, hide the pill and say so in the summary.

## 6. Home integration

The Home redesign already reserves `HomeSectionKind.islamicCalendar` and `HomeShortcut.islamicCalendar` (hidden). This feature turns them on. If the Home redesign has not landed, stop and ask before inventing a different mechanism.

- **Today card section** (`islamicCalendar` kind, lives under the pinned next-prayer card): today's Hijri date large, Gregorian date, a small `MoonView` with phase name and illumination %. Tap → `HijriCalendarView` with today selected. Moon info is for "now" and refreshes on foreground and day rollover (reuse the Home `ClockService`). If an upcoming occasion is ≤7 days away, add one line "بعد ٣ أيام: يوم عرفة".
- **Shortcut:** enable `HomeShortcut.islamicCalendar` (icon `calendar` / crescent glyph, label "التقويم الهجري") in the shortcuts grid and the customization screen. Flip its availability check to true. Don't change the stored-data shape.
- Existing users have the new kinds stored as hidden, so they won't see it until they enable it; new installs get it visible after `nextPrayer`. Mention this in the summary.
- Route via `AppRoute.hijriCalendar(selecting: Date?)` so the card, shortcut, and any future widget deep-link share one destination.

## 7. Structure

```
Domain/Calendar/        HijriDay, HijriMonth, MonthGrid, IslamicOccasion, OccasionRule,
                        MoonInfo, MoonPhase, repository + service protocols, use cases
Core/Moon/              AstronomicalMoonCalculator
Data/Calendar/          BundledOccasionsRepository, DTOs
Features/Calendar/      Views (HijriCalendarView, MonthGridView, DayCell, MoonCard, MoonView,
                        MoonDetailView, OccasionRow, OccasionDetailSheet, OccasionsYearView),
                        ViewModels, CalendarCoordinator
Resources/.../         IslamicEvents.json  (existing file, extended, not replaced)
```

Keep every `body` small (extract subviews over ~60 lines). `HijriCalendarViewModel` is `@MainActor @Observable`, composes use cases only, and exposes plain state (`visibleMonth`, `selectedDay`, `grid`, `moon`, `occasions`, `showGregorian`).

## 8. Localization, RTL, accessibility

- Every string in the String Catalog (AR + EN). Build and verify Arabic first, then English.
- Leading/trailing only. Use `chevron.forward` / `chevron.backward` semantics so the month arrows read correctly in RTL (in Arabic, "next" points left).
- Day cell `accessibilityLabel`: full Hijri date + Gregorian date + weekday + occasion names. Month paging exposes `accessibilityAdjustableAction` (next/previous month).
- Verify the grid at the largest Dynamic Type. The Gregorian sub-label must degrade gracefully (hide it at accessibility sizes before truncating).
- The moon card reads as one element: "Moon tonight: waxing gibbous, 79 percent illuminated, 391,700 kilometres".

## 9. Build order, one slice per commit (on the branch from §0)

1. **Hijri month grid domain** + `MonthGrid` generation (29/30 days, week start, offset) + tests. No UI.
2. **Moon engine** + tests (§3.3) + `MoonView` drawing with a preview showing all 8 phases and both hemispheres.
3. **Occasions**: extend existing IslamicEvents.json, repository, date resolver, upcoming use case + tests (resolve every rule for a known Hijri year; year-wrap case).
4. **`HijriCalendarView`**: header, month pager, native-style grid, selection, Gregorian toggle, Today button, month/year picker.
5. **Moon card + `MoonDetailView`** and the occasions list, `OccasionDetailSheet`, `OccasionsYearView`.
   - **Photographic moon (do this in this slice):** upgrade `MoonView` to a real NASA moon photo. I will put a public-domain NASA full-moon texture in Resources; never download it yourself. If the file isn't there, keep the drawn moon and say so. Draw the texture as a circle, darken the unlit part with the existing terminator path using a soft feathered edge (earthshine: unlit side at about 6-10% brightness, not pure black). Keep the inputs `illuminatedFraction`, `isWaxing`, `hemisphere`; never flip for RTL. Add NASA credit to the About attribution screen and ask me to confirm the license on the exact file's page. Keep the 8-phase preview and add a screenshot of it. The optional 3D moon (slice 8) reuses the same texture.
6. **Home integration** (today card, shortcut, routing).
7. **Settings** (Gregorian toggle, week start, recurring-dots toggle), About attribution (Meeus reference, any moon texture), accessibility and RTL pass.
8. *(Optional)* 3D moon.

## 10. Definition of done, per slice

- Clean build, **no warnings**, iOS and macOS, via the `xcodebuild` commands in `CLAUDE.md`. All tests pass.
- Simulator checks: Arabic RTL, English LTR, light and dark, largest Dynamic Type. Screenshots: current month, a month swiped to, Gregorian labels on and off, moon card on a new/quarter/full/crescent day, moon detail, an occasion sheet, Home today card.
- No `AnyView`, no view `body` over ~60 lines, no `ObservableObject`, no hardcoded strings, no network use (everything works in airplane mode).
- Final summary lists: files added/changed, moon-algorithm constants you verified vs. couldn't, every occasion record whose source/virtue is unverified, and any license blockers.

## 11. Ask me before starting if

- The Home redesign (sections + `HomeLayout`) isn't merged yet.
- `HijriDateService` doesn't already apply the day offset, or doesn't expose month length / Hijri→Gregorian conversion.
- `PrayerTimeEngine` can't give Maghrib for an arbitrary date.
- You find a conflicting existing calendar screen.
- Optional notifications for occasions are wanted. They are out of scope here, because they'd share the 64-notification budget with prayers and adhkar.
