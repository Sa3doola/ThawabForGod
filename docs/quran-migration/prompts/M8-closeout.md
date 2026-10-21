# M8 close-out: open bugs, then a short clean run

New session, `/model sonnet`. Pipeline per fix: quran-architect (opus, short note) → implementer (sonnet) → build → the affected tests only → rules-checker (haiku) → quran-reviewer (opus) → commit with `Agents:` and `Tests:`. Hard limits: **two fix rounds per bug**, **no full matrix**, keep `caffeinate -dimsu` running, and no single test may run longer than 3 minutes (kill and report it).

Saad's decisions:
- **B7 Mac Arabic mirroring:** find the cause in at most two attempts: check what `Bundle.main.preferredLocalizations`, `NSApp.userInterfaceLayoutDirection` and the root `\.layoutDirection` report under `-AppleLanguages (ar)`, whether `ar.lproj` actually ends up in the built Mac bundle, and whether anything in the app root pins `.leftToRight`. If the system window still won't mirror, use the fallback: the app's content (sidebar list, toolbars, reader, panel) follows `AppLanguage` via `\.layoutDirection` at the root on macOS, and the window chrome stays as macOS draws it. Then `testSidePanelInArabicIsLeading` must pass.
- **B12 Page tab (full data, iPhone Air + Duo):** first decide app bug vs test. Open the Library on the Page tab in full data on the Duo with a screenshot. If the grid shows, fix the tests: reach page 50 with the go-to field or `scroll_to` by identifier, never by walking 604 cells. Same for `QuranLibraryScreenshotTests.testEachIndex` (the 17-minute walk).
- **B13, B14, B15:** triage each in one run on its destination (Duo / iPad / Duo). App bug → fix; stale test assumption (e.g. the Duo's side tab bar) → fix the test and say why.
- **B11 (four Mac skips):** one more attempt each, max 15 minutes total; otherwise leave them skipped with the reason and they go to Saad's manual list.
- **B10:** stays manual (Saad, VoiceOver on iPad).
- **B9 commit had no rules-checker/reviewer:** run both on `0b9a49e` now; fix anything blocking.

Then **one clean confirmation run** on HEAD, QuranPlatformTests only, on iPhone Air, iPhone Duo, iPad Pro 13 and Mac, plus the unit tests on iOS and macOS. Look at 10 of the widget PNGs (ar/en, full/public, each family) and say in one line each whether they look right.

Update `TEST-REPORT.md` (new section "Close-out", don't rewrite the history) and `BUGS.md`. Stop. Do not merge.
