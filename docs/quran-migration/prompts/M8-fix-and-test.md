# M8: fix the reported bugs, finish the migration, then test on every platform

New session, `/model sonnet` for the main agent. Read `CLAUDE.md`, `QURAN_MIGRATION_PLAN.md` §4, `docs/quran-migration/BUGS.md`, and the design notes the bugs touch. This replaces `M8-lean.md` (commit both prompt files and `BUGS.md` in the first commit).

**Lean mode ends for this milestone:** tests are written and run again. Keep usage in check: build once per destination, run each suite once, re-run **only failing tests** (`-only-testing:`), pipe xcodebuild through `grep -E "error:|warning:|Test Case.*(failed|passed)|\*\* "` and read results with `xcrun xcresulttool` summaries, never full logs.

## Models (all three on every phase)
| Model | Agent | Job here |
|---|---|---|
| Opus | `quran-architect` | Root cause and fix design for B1, B2, B3, B4 (≤120 lines per note, one note per bug: `design/M8-B<n>.md`) |
| Opus | `quran-reviewer` | Reviews every fix before commit; reviews the final test report |
| Sonnet | `feature-implementer` | The fixes and M8.1-M8.2 work, disjoint files |
| Sonnet | `ui-test-writer` | XCUITest flows for every bug (a regression test that fails before the fix) and the platform suites in Phase C |
| Haiku | `test-porter` | Unit tests (widget snapshot/provider, tap handling, deep links, panel layout rules) |
| Haiku | `rules-checker`, `l10n-porter` | Every commit |
| Haiku | `migration-scout` | Summarise crash reports and failing xcresult bundles into a table (file, test, error line) so the main agent doesn't read raw logs |

## Destinations
Confirm exact names first with `xcrun simctl list devices available` and record them in the report.
- iPhone 18 Pro, iOS 27.0
- iPhone Duo, iOS 27.1 (unfolded, folded, tabletop)
- iPad (the newest iPad Pro 13-inch runtime installed; portrait, landscape, Split View)
- Mac (`platform=macOS`). If UI automation fails to start ("timed out while enabling automation mode"), stop and ask Saad to run `sudo automationmodetool enable-automationmode-without-authentication` and allow Xcode under Privacy & Security → Accessibility, then continue.

## Phase A: fix the bugs (one commit per bug, pipeline: architect → implementer → l10n → build iOS+macOS → regression test written and run on the affected destinations → rules-checker → reviewer → commit)
- **A0 Strings:** `Shared/Resources/Localizable.xcstrings` has an uncommitted Xcode change (+574/−281, an empty `""` key, `cancel_action`…). Keep only entries an `L10nKey` uses, drop auto-extracted junk, keep `extractionState: manual` style, commit alone.
- **B1 Crash on tab switch with the reader open.** Reproduce on iPhone 18 Pro first, read the crash report (`~/Library/Logs/DiagnosticReports`, simulator logs) and the stack. If not obvious, `git bisect` between `214d043` (M6.4) and `HEAD` with a UI test that opens the reader and taps Settings, then Home. Suspects to check, not assume: M7.2 key responder / key monitor and `focusedSceneValue`, M7.3 bottom panel and hidden tab bar, M5.1 immersive chrome, the `.id(selectedTab)` split-view fix, typed paths. Fix the cause; test on iPhone, Duo and iPad (tab bar and sidebar).
- **B2 Mac: surah tap doesn't open the reader.** Expected cause: the reader's `.inspector` (macOS only now) pops the pushed reader, the same SwiftUI behaviour M7.1 found on iPad. **Replace `.inspector` everywhere with our own trailing side panel inside the reader** (an `HStack` with a fixed/resizable column, divider, close button, the existing `AyahPanel` view; shown at regular width on iPad landscape and Mac, sheet at compact width, Duo per M7.3). This also gives iPad its side panel back and supersedes M8.0. Remove `quranPanelInspector`; update `AyahPanelLayout` and its comment. Test Mac and iPad.
- **B3 No tap-to-turn.** Remove page turning from taps entirely (`MushafTapZones`: edge zones, `turnsPage`, its callers). A tap on words always selects the ayah; a tap outside the text toggles the chrome (immersive) as before. Pages change only by swiping/scrolling the pager, plus keyboard and menu on iPad/Mac (M7.2). Also find **why a turn jumped to the last page** instead of the next one (RTL index mapping in the pager?) and fix that path too, since the keyboard/menu still use it. Test: tap the first and last word of several lines on pages 1, 2, 50, 604; swipe both directions; keyboard ← → on iPad/Mac.
- **B4 Ayah of the Day widget.** Diagnose end to end and write down what was wrong: the JSON in the app bundle (both profiles); the publisher actually running and writing `QuranWidgetSnapshot` to the App Group (same suite name and entitlement in app and widget); 30 days present, today's entry chosen in the device's time zone; text/reference/translation; the Hafs face copied and registered in the widget process; timeline reload at midnight; tap opening `noor://quran/verse/s/v`. Unit tests for the provider and the day rule; render each widget family with `ImageRenderer` in a test to PNG (into the ignored `Screenshots/quran-migration/M8/widgets/`) and look at them. Same checks for Continue Reading.
- **B5 and anything Saad added to `BUGS.md`**, in order.

Mark each bug in `BUGS.md` with its commit.

## Phase B: finish the migration (from M8-lean.md, lean pipeline)
- **M8.1 Leftovers:** remove the unused generic `BookmarkRecord` / `SwiftDataBookmarkRepository` stack if only tests use it; dead `L10nKey`s with no caller; leftover legacy Quran references; `Tools/*.rb` for project changes.
- **M8.2 Docs:** rewrite the Quran entry in `CLAUDE.md` and `ARCHITECTURE.md` as built (including: Quran text never altered, highlight = attributes only, nothing QUL-derived committed, never `.inspector` inside the split detail column, no tap-to-turn); README sources table; Corpus README; `Resources/Licenses` complete; no `TODO(license)`.
- **M8.3 Release check:** size report for both profiles (200 MB budget), offline proof, `git status --ignored` shows no tracked QUL file, Release build of the public profile without full data → `docs/quran-migration/RELEASE-CHECK.md`.

## Phase C: full testing on the four destinations
1. **Unit tests** (iOS on iPhone 18 Pro, and macOS): the whole suite, then fix failures (app bug → fix + reviewer; stale test → update, say why).
2. **UI test suite** `QuranPlatformTests` (Sonnet writes, Opus reviews the plan first), run on all four destinations, in **full** and **public** data modes (`-quranData public`), light and dark, English and Arabic for the flows marked *:
   - Library: tabs, go-to field (surah, s:a, juz, hizb, page; refusal in public), filter*, Continue reading bar.
   - Reader: open from surah/juz/hizb/page; swipe paging both ways; taps select, never turn; immersive chrome on iPhone; Mushaf ↔ separated keeps place; Next surah.
   - **Tab/section switching with the reader open, from every tab, repeated 5 times (B1).**
   - Ayah panel: sheet (compact) and side panel (iPad landscape, Mac); translation/tafsir, copy, bookmark, note, highlight.
   - Bookmarks list; search* (highlight, open result, recents); settings sheet and Settings → Quran; Sources.
   - Home Continue card and recent-activity chip; deep links `noor://quran`, `/verse/2/255`, `/page/50`.
   - Relaunch keeps the reading position (terminate + launch).
   - iPad: rotation and Split View with panel open; hardware-keyboard shortcuts (⌘F, ⌘G, ⌘D, ⌘[ ⌘], arrows).
   - Duo: unfolded spread, folded, tabletop bottom panel (DEBUG `-quranFold`, `-quranFoldHorizontal`), fold changes with the panel open.
   - Mac: sidebar navigation into the reader (B2), Quran menu items enabled only in the Quran section, window resize spread ↔ single page, Settings (⌘,) Quran tab.
   - Accessibility: largest text size on iPhone Library and reader; VoiceOver one element per ayah (audit with `XCUIApplication().performAccessibilityAudit()` where the OS supports it).
3. **Widgets:** the `ImageRenderer` PNGs for every family in both data modes, plus Arabic/English; check the deep links each widget emits.
4. **Screenshots** of the main screens per destination into `Screenshots/quran-migration/M8/<device>/` (ignored), light and dark.
5. **Performance spot check** with `measure-performance.sh`: first page, paging 1→604, memory; compare with the M4 numbers.

Every failure becomes a line in `BUGS.md`, gets fixed with the Phase A pipeline, and the failing tests are re-run on the destinations they failed on. Stop fixing after two rounds per test and report what's left.

## Stop report → `docs/quran-migration/TEST-REPORT.md` (Opus reviews it)
A table **destination × area → pass / fail / skipped (why)**, the bug list with commits, test counts per destination, performance vs M4, the widget PNG paths, what could not be automated, and a short **manual pass for Saad** (only what automation can't cover: real Duo hardware, real widgets on the Home Screen, haptics, Mac menu bar feel). Then wait for Saad before merging `quran-migration` into `Development`.
