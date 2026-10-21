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

---

# 10. Close-out (2026-10-21, after `0b9a49e`)

The sections above are the history and are not rewritten. Commits: `b1ee029` (B7, B9 follow-ups, B11 copy, B13, B14, B15) and `7610637` (B16). HEAD for the clean run is `7610637`; the working tree also carries two uncommitted Xcode re-saves (`project.pbxproj`, `Localizable.xcstrings`) that are not mine and were not committed.

## 10.1 Per bug

| Bug | Result | Agents | Tests |
|---|---|---|---|
| B9 review (`0b9a49e` had none) | rules-checker: no blockers. quran-reviewer: no blockers; applied the title overlap fix (`lineLimit`, padding) and the stale script/CLAUDE.md text. Not done: pushed Packs/Sources pages with the hidden root bar were not checked on a device. | rules-checker, quran-reviewer | covered by the clean run |
| B7 Mac Arabic | **Fixed by the fallback, cause not found.** Probe: `preferredLocalizations = ["ar"]`, `ar.lproj` is in the built bundle, nothing pins left-to-right, yet `NSApp.userInterfaceLayoutDirection` is 0 (LTR) at init and after launch. On macOS `LocalizedModifier` now sets `\.layoutDirection` from `AppLanguage` at the root. Sidebar is on the right, panel on the left. **New B17: the reader's toolbar items collapse into the overflow menu in that mirrored window** (screenshot seen); the Arabic Mac test therefore no longer waits for the Library button. | rules-checker, quran-reviewer (no blockers; one rules "fail" on an inline `#if os(macOS)` in `Shared/`, which CLAUDE.md allows) | `testSidePanelInArabicIsLeading` passes on the Mac (was skipped) |
| B12 Page tab | **Can't reproduce.** Both tests pass on iPhone Air (19 s, 20 s) and Duo (17 s, 33 s); `testEachIndex` passes on the iPad in 36 s. The grid shows. No change made. | none | as stated |
| B13 Duo immersive | **Test assumption.** The Duo has no bottom tab bar XCUITest reports; the tab-bar asserts apply only where one exists. | reviewed with B7 | passes on Duo, iPhone Air; iPad skips by design |
| B14 iPad immersive | **App bug, fixed.** Tapping the page footer opened the ayah panel on the iPad (probed by coordinate: footer text and the gap above it did). The footer now has its own hit shape and the chrome toggle. Cause (the last line's tall glyph boxes) is inferred; the reviewer could not confirm it from the diff, and the gap just above the footer still selects the last ayah. | rules-checker, quran-reviewer | `QuranImmersiveTests` on iPad, iPhone Air, Duo |
| B15 Duo surah info | **Test assumption.** The Duo draws the system `BackButton` outside the navigation bar element; `tapBack()` falls back to it. | same | `QuranSurahInfoTests` on Duo |
| B11 Mac skips | **One of four fixed**: `testPanelCopy` (the panel draws stored text + NBSP + end marker; Copy puts the stored text on the pasteboard). Three still skip: Notes segment, Home chip, tafsir Read more (the button exists, no sheet appears). Stopped at the 15-minute cap. | none | `testPanelCopy` on Mac |
| B10 | Left manual (Saad, VoiceOver on the iPad). | | |
| B16 widget gallery grey bar | **Fixed in code, not verified on a device, cause not confirmed.** See 10.3. | rules-checker, quran-reviewer (should-fix items applied) | 32 widget tests on iPhone Air |

## 10.2 Clean confirmation run on `7610637`

`QuranPlatformTests` only, plus unit tests. Logs in the session scratchpad (`clean_*.log`); builds produced 0 warnings in the iOS unit run.

| Destination | Result | Time |
|---|---|---|
| iOS unit (iPhone Air) | 1188 tests, all pass | 16:57 to 16:58 |
| macOS unit | 1183 tests, all pass | 16:58 to 16:59 |
| iPhone Air, `QuranPlatformTests` | 18 pass / 0 fail / 8 skipped | 8.4 min |
| iPhone Duo | 22 / 0 / 4 | 10.4 min |
| iPad Pro 13 (M5) | 21 / 0 / 5 | 11.5 min |
| Mac | 19 / 0 / 10 | 6.9 min |

The Mac's 10 skips: the three B11 tests above; four Duo-only tests; iPhone-only `testLargestTextReader`; iPad-only `testPadRotationKeepsPanel`; `testSettingsQuranAndSources` (the Mac uses the Settings window). **Not run:** the existing UI suite, Arabic runs, public-data runs, dark runs (unchanged from section 7), and unit tests on the Duo and iPad. The matrix is still not complete.

## 10.3 B16 measurements (simulator test process, not the extension)

- Decoding a 532 KB snapshot of 250 long entries: 2.7 ms; trimmed to the days kept: 17 KB.
- One large Ayah of the Day render with the Hafs face registered, a 99 KB real snapshot decoded and trimmed (10 of 125 entries kept): footprint grew about 1.2 MB. Hafs and Amiri are 430 KB together.
- So the suspected causes (decode time, memory, the two fonts) are **not supported** by these numbers, and the real cause of the grey bar is unknown. What changed: previews (`placeholder`, `getSnapshot` with `isPreview`) return the bundled sample (`Shared/Resources/quran-widget-sample.json`, Tanzil 94:5-6, checked against the corpus by a test) with no App Group read, no font work and no list decode; the Ayah timeline keeps today plus seven days (plus a day either side for a time-zone change); Continue Reading keeps none of the list; font registration runs once per process. The preview therefore shows the reference only (`hasHafs` false), not the Arabic.
- Needs a real device with Console (jetsam / `chronod`) to separate: extension killed for memory, slow first `getSnapshot`, a cached failed gallery snapshot.

## 10.4 Widget PNGs reviewed (10 of 128)

All were rendered by the unit test host, which runs in English, so the Arabic files show English labels ("Ayah of the day", "Continue Reading", "Verse"); that is the test host's bundle language, not seen on a device.

1. `ayah-large-2-255-ar-full`: right. Whole ayah with marks and end marker, translation clipped with an ellipsis, credit line.
2. `ayah-large-2-255-en-public`: right. Tanzil text without the pause marks, translation under it.
3. `ayah-medium-25-63-en-full`: right, both lines whole.
4. `ayah-medium-112-1-4-ar-public`: right; reference reads 112:1 to 4 in Arabic-Indic digits.
5. `ayah-rectangular-1-1-7-en-full`: acceptable; one line of Arabic ending in an ellipsis over the reference.
6. `ayah-medium-2-255-ar-full`: right; three lines, ends with an ellipsis by design.
7. `ayah-large-112-1-4-en-full`: right; the markers 1 to 4 sit where they should.
8. `continue-small-2-255-ar-full`: right apart from the English label noted above.
9. `continue-medium-25-63-en-public`: right.
10. `continue-large-112-1-4-ar-public`: looks right but nearly empty below the three lines; the large Continue Reading card is mostly white space.

## 10.5 Open after close-out, for Saad

- **B16 on a real iPhone** (check the gallery after a fresh install; a Home Screen widget across midnight; a time-zone change with no launch).
- **B17**: decide whether Arabic Mac readers accept mirrored content with the reader's toolbar in the overflow menu, or the fallback should wait for a better route.
- B10 (VoiceOver on the iPad panel); B11's three Mac tests (manual pass: Notes segment, Home chip, tafsir Read more); B5 (never described).
- Also unchecked on a device: the B9 header with the pushed Packs and Sources pages, and the B14 gap just above the footer still selecting the last ayah.
- Still not merged. `quran-migration` is not ready for `Development` until B16 and B17 are decided.

