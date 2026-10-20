# Quran migration: bug list

Saad adds bugs here (one line each: device, OS, steps, what happens, what should happen). Claude Code fixes them in order, marks them `[fixed <commit>]` or `[can't reproduce: why]`, and never deletes a line.

## Open (reported 2026-10-20)
- **B1 Crash (iPhone, iPad, Duo):** open the reader (Mushaf page), then tap another tab (Settings or Home) → the app crashes. [fixed 56de81f]
- **B2 Mac:** tapping a surah in the Library does not open the reader. [fixed 4f8d868; Mac UI tests pass 2026-10-21]
- **B3 Mushaf taps (all):** tapping the first word of a line turns the page and jumps to the last page. Wanted: taps never turn pages; pages change only by swiping/scrolling (plus keyboard and menu on iPad/Mac). [fixed 61c172b; Mac paging tests pass 2026-10-21 after B6; last-page jump cause inferred, not reproduced]
- **B4 Ayah of the Day widget:** doesn't work as expected (details to confirm while testing: empty, wrong ayah, wrong day, no Arabic font, tap does nothing). [fixed a2ec6e4 on paper; causes found by reading code, not observed on a Home Screen; manual widget pass pending]
- **B5 iPad / iPhone Duo:** more issues seen; Saad adds them below.

## Added by Saad
- 

## Found while testing (M8 Phase C, 2026-10-21)
- **B6 Mac: ← / → do not page.** Mac, Mushaf reader: the plain arrow keys (menu key equivalents) never fire while the reader's scroll view has focus; Space and Page Up/Down (event monitor) did. Confirmed with real keystrokes from System Events, not only XCUITest. [fixed: arrows moved to the event monitor in `QuranKeyInput`; `testArrowKeysFromPage50/604` pass on the Mac]
- **B7 Mac, Arabic: the window is not mirrored.** Launching with `-AppleLanguages (ar)`: menu bar and labels are Arabic, but the sidebar stays on the left and toolbar/panel on the LTR side; the reader's side panel follows the window, so it is on the right. Not caused by M8 (nothing sets `layoutDirection`; `knownRegions` is still `(en, Base)`). [open: needs a decision on how the Mac gets RTL; `testSidePanelInArabicIsLeading` skips with this reason until then]
