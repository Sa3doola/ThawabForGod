# Quran migration: bug list

Saad adds bugs here (one line each: device, OS, steps, what happens, what should happen). Claude Code fixes them in order, marks them `[fixed <commit>]` or `[can't reproduce: why]`, and never deletes a line.

## Open (reported 2026-10-20)
- **B1 Crash (iPhone, iPad, Duo):** open the reader (Mushaf page), then tap another tab (Settings or Home) → the app crashes. [fixed 56de81f]
- **B2 Mac:** tapping a surah in the Library does not open the reader. [fixed 4f8d868; Mac UI test pending: screen was locked]
- **B3 Mushaf taps (all):** tapping the first word of a line turns the page and jumps to the last page. Wanted: taps never turn pages; pages change only by swiping/scrolling (plus keyboard and menu on iPad/Mac). [fixed 61c172b; Mac paging test pending; last-page jump cause inferred, not reproduced]
- **B4 Ayah of the Day widget:** doesn't work as expected (details to confirm while testing: empty, wrong ayah, wrong day, no Arabic font, tap does nothing). [fixed a2ec6e4 on paper; causes found by reading code, not observed on a Home Screen; manual widget pass pending]
- **B5 iPad / iPhone Duo:** more issues seen; Saad adds them below.

## Added by Saad
- 
