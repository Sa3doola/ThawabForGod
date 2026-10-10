# madaniV2: the Madani V2 page fonts

This folder is a **folder reference** in the app target (added by `Tools/add_quran_data_phase.rb`),
so its contents are copied into the app bundle as `madaniV2/`, path and all.

In this repository it holds only this README. The 604 page fonts (`p1.ttf` … `p604.ttf`, PostScript
names `QCF2001` … `QCF2604`, about 200 MB) come from the Quranic Universal Library, which publishes
no licence for them, so they are never committed. On a machine with the QUL downloads in
`QuranData/raw/`, fill the folder with:

    swift run -c release --package-path Tools/QuranBuilder QuranBuilder --profile qul

which verifies every file against `QuranData/fonts-v2.sha256` before copying it here.

- **Debug** builds work with or without the fonts. Without them the "Check Quran full data" build
  phase prints a warning, and the app hides Mushaf mode (separated mode on the Tanzil text).
- **Release** builds fail without them, so a full App Store build cannot ship incomplete.
- At launch `FontRegistrar` skips this folder (`QuranPageFonts.folderName`); the page renderer
  registers the fonts a few pages at a time.

See `QURAN_MIGRATION_PLAN.md` (T1, T4, T14) and `QuranData/SOURCES.md`.
