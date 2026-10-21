# M8 test report (Phase C), 2026-10-21

Branch `quran-migration`, head `0b9a49e`. **The UI matrix and the two Arabic runs measured `0cd1122`** (11:39 to 14:26), not the head: they ran before the B9 header and `knownRegions` changes. Only the B9/B7 tests, the unit runs and the builds ran on `0b9a49e`. Xcode 27.1, iOS 27.0 / 27.1 simulators, macOS.

**This report is partial, on purpose.** The full Phase C matrix was stopped after about two and a half hours
(11:39 to 14:12) because the rest would have taken more than an hour more; what had run was kept, and only the extra combination below
was added. Section 7 lists exactly what was not run. Nothing here is rounded up.

## 1. Destinations actually used

There is no iPhone 17 or 18 Pro simulator on this machine.

| Prompt's name | Used | Id |
|---|---|---|
| iPhone 18 Pro, iOS 27.0 | **iPhone Air**, iOS 27.0 | `DA421EEC-...` |
| iPhone Duo, iOS 27.1 | iPhone Duo, iOS 27.1 | `69C7A8F4-...` |
| iPad | iPad Pro 13-inch (M5), iOS 27.0 | `FCF7A3DF-...` |
| Mac | macOS (this Mac) | |

## 2. Destination x area

Counts are `Test Case` lines from the logs in `/tmp/phase_c/`: pass / fail / skipped. "Platform" is the new
`QuranPlatformTests` (26 tests on iOS, 29 on macOS, which has Mac-only tests); "existing" is every other UI test in `ThawabForGodUITests`. Full data, light,
English unless a row says otherwise.

| Destination | Unit | Platform suite | Existing UI suite | Arabic + public data (2 starred tests) |
|---|---|---|---|---|
| iPhone Air | 1183 pass | 18 / 0 / 8 | 57 / 2 / 11 | **pass** (both) |
| iPhone Duo | not re-run | 22 / 0 / 4 | 53 / 4 / 13 | not run |
| iPad Pro 13 | not re-run | 21 / 0 / 5 | **cut off**: 15 / 1 / 2 when stopped | not run |
| Mac | 1178 pass | **not run in the clean matrix** (see below) | **not run** | **pass** (both) |

- Unit tests: 1183 on iPhone Air and 1178 on macOS (the difference is iOS-only tests), run on the code of
  `0b9a49e` (logs `/tmp/phase_c/unit_id_DA...log` and `unit_platform_macOS_.log`), no warnings.
- **Mac platform suite.** Its last full-suite result came from running the tests one by one while fixing them (all
  pass except four skipped, BUGS.md B11). The clean matrix never reached the Mac, so there is no single clean Mac
  run. The earlier commit message for `0cd1122` says the phones and iPad "all pass": the clean runs above
  confirm that (0 failures on all three).
- Skips are by design: Mac-only or iPhone-only tests on the other platform, the four Mac tests in B11, and the
  Arabic side-panel test (B7).
- The Arabic + public run was launched with the whole platform suite by mistake, so 9 other tests failed on each
  of iPhone Air and Mac. They were **not triaged**; they are presumed to be English label lookups, but some may
  be public-data or Arabic behaviour. They are not counted in the table. As a result the accessibility audit and
  the one-element-per-ayah test have **no passing Arabic or public-data result**. The two tests written for Arabic, `testLibraryFilterArabic` and
  `testSearchOpensResultAndRemembers`, passed on both.
- Settings sheet after the B9 fix: `testReaderSettingsSheet` passes on iPhone Air, iPad, Duo and Mac.

## 3. Bugs

All lines are in `docs/quran-migration/BUGS.md`.

| Bug | Status | Commit |
|---|---|---|
| B1 crash leaving the reader for another section | fixed | `56de81f` |
| B2 Mac: tapping a surah did nothing (inspector) | fixed | `4f8d868` |
| B3 page turning (tap zones, last-page jump) | fixed; last-page-jump cause inferred, never reproduced | `61c172b` |
| B4 widget stuck on the last of 30 days | fixed on paper; never seen on a real Home Screen | `a2ec6e4` |
| B5 "more issues on iPad / Duo" | **no details were ever given**; nothing done | |
| B6 Mac arrow keys did not page | fixed | `95864d7` |
| B7 Mac Arabic window not mirrored | **open**: `ar` in `knownRegions` and `CFBundleLocalizations` both tried, neither mirrors | `0b9a49e` (knownRegions only) |
| B8 Quran menu items always disabled | fixed | `0cd1122` |
| B9 Duo Reading Options bar scrolled away | fixed | `0b9a49e` |
| B10 iPad audit: three unmapped text elements | **open**, needs a manual VoiceOver pass | |
| B11 four tests skip on Mac | **open** (pass on iOS) | |
| B12 Page tab tests fail on iPhone Air and Duo | **open, not triaged** | |
| B13 Duo immersive test: "reader sits inside the tab bar" | **open, not triaged** | |
| B14 iPad `testIPadHasNoImmersiveMode` | **open, not triaged** | |
| B15 Duo `testSurahInfoOpensAndGoesBack` | **open, not triaged** | |

B12 to B15 came from the existing suite in the full run. No fix round was spent on them, because the matrix
was stopped. Whether each is an app bug or a test assumption is not known. B12's second test took about 10.5 minutes (Duo) and 18.6 minutes (Air) before failing, and the iPad run was
stopped about 17 minutes into `QuranLibraryScreenshotTests.testEachIndex`, the same slow element walk; that alone is worth a look.

## 4. B1 to B11: agents and tests each fix really had

The B1 to B4 commits were made before the `Agents:` / `Tests:` lines were required, so their rows are
reconstructed from what ran in the session, not from the commit messages, so the test counts and agent lists in
those four rows are **unverifiable** from the repository. "Mac later" means the Mac was not
available when the fix was made (the screen was locked) and was checked afterwards, in the commits named.

| Bug | Commit | Agents | Tests |
|---|---|---|---|
| B1 | `56de81f` | quran-architect, ui-test-writer, rules-checker, quran-reviewer | `QuranSectionSwitchTests` on iPad M5, iPhone Air, Duo. Mac later (`95864d7`). |
| B2 | `4f8d868` | quran-architect, feature-implementer, test-porter, ui-test-writer, rules-checker, quran-reviewer | `AyahPanelLayoutTests` (macOS); `QuranSidePanelTests` on iPad and iPhone Air. Mac later (`95864d7`). |
| B3 | `61c172b` | quran-architect, feature-implementer, test-porter, ui-test-writer, rules-checker, quran-reviewer | `MushafPagerStepTests` (20, iPad); paging UI tests on iPad and iPhone Air. Mac later: failed until B6, passed after `95864d7`. |
| B4 | `a2ec6e4` | quran-architect, 3 x feature-implementer, test-porter, rules-checker, quran-reviewer | 27 widget unit tests on iPhone Air; macOS build. **Not run on a Home Screen.** Widget PNGs rendered from tests. |
| B5 | none | none | none (no details given) |
| B6 | `95864d7` | none (main agent only) | macOS UI: `QuranSectionSwitchTests`, `QuranSidePanelTests`, `QuranPagingTests` pass; Arabic panel test skips (B7). |
| B7 | `0b9a49e` | none | Mac: `testSidePanelInArabicIsLeading` still skips. **Not fixed.** |
| B8 | `0cd1122` | quran-architect (test plan), ui-test-writer x3, rules-checker, quran-reviewer (no blockers; should-fix items applied) | `QuranPlatformTests` all pass on iPhone Air, iPad, Duo; Mac pass except four skipped; unit iOS 1183, macOS 1178. |
| B9 | `0b9a49e` | none (no rules-checker or quran-reviewer run on this commit) | `testReaderSettingsSheet` on Duo (with only the bar pinned it failed, seen while fixing and not kept in a log; passes with the header), then iPhone Air, iPad, Mac; unit iOS 1183, macOS 1178. |
| B10 | none (Mac go-to label only, in `0cd1122`) | as B8 | Audit test attaches the iPad findings instead of failing. |
| B11 | none | as B8 | Four tests skip on Mac. |

`5f72daf` (`.omc/` ignore, licence docs) carries `Agents: none` and `Tests: none run`.

## 5. Performance against M4

**Not measured.** `Tools/QuranBuilder/scripts/measure-performance.sh` was not run in this session, so there is
no first-page, paging 1 to 604 or memory number to compare with M4. Release size was measured and is in
`RELEASE-CHECK.md`: full data 154 MB deflated on the Mac and 163 MB on the iOS simulator build, against the
200 MB budget.

## 6. Widgets

Rendered by `QuranWidgetRenderTests` as PNGs, 128 files, git-ignored, both data modes and both languages:
`Screenshots/quran-migration/M8/widgets/` (for example `ayah-large-1-1-7-ar-full.png`,
`ayah-large-1-1-7-ar-public.png`, `ayah-large-1-1-7-en-full.png`). **They were not reviewed by eye for this
report.** Per-device screenshots of the app (`Screenshots/quran-migration/M8/<device>/`) were not taken in
this session either, apart from the test-attached ones.

## 7. What was not run, and what cannot be automated

Not run:

- The Mac platform suite and Mac existing suite as clean matrix runs.
- Public-data, dark runs (Run 2) on all four destinations.
- The Arabic starred tests on iPad and Duo; all Arabic runs of the existing suite.
- The existing suite on the iPad (cut off) and the remainder after it.
- Full-data Arabic runs (both Arabic runs used public data), and the surah-info test, which skips unless the
  bundle is public-only.
- A re-run of the matrix on `0b9a49e`.
- Performance spot check, widget PNG review, device screenshots, unit tests on the Duo and iPad.

Cannot be automated here: the real Duo hardware fold, real Home Screen and Mac desktop widgets, haptics, VoiceOver
on the iPad side panel (B10), the Mac menu bar feel, and Mac window mirroring in Arabic (B7: needs a way found
first). Also: Mac text input into the go-to field is not asserted (XCUITest focus), and the audit cannot see
background colours (search highlights).

## 8. Manual pass for Saad

1. **Real Duo:** fold and unfold with the reader open (spread, panel on the trailing half, tabletop).
2. **Widgets on a real Home Screen** (iPhone) and the Mac desktop: add Continue Reading and Ayah of the Day; open the
   app, read a page, check they update; set the date a month ahead and check Ayah of the Day still changes.
3. **Haptics** on a phone when selecting an ayah.
4. **Mac menu bar:** the Quran menu (items enabled only in the Quran section), arrow keys and Space while the
   reader has focus, ⌘F and ⌘G, ⌘[ ⌘].
5. **iPad with VoiceOver** on the ayah side panel (B10).
6. **Mac in Arabic:** whether the window should mirror (B7); decide how.
7. **Side effects of B1's whole-split-view `.id`:** sidebar width after switching sections, arrow keys in the
   sidebar, ⌘1 to ⌘4, tapping the current section twice.
8. **Duo Reading Options sheet** after the B9 header change, in both languages.
9. Tell me what B5 was.

## 9. Before merging

Do not merge `quran-migration` into `Development` yet: B7, B10 to B15 are open and the matrix is incomplete. That
is for Saad to decide; nothing has been merged.
