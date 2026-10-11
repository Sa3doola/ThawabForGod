# M5 remainder, lean mode

Run on Sonnet (`/model sonnet`). Follow `QURAN_MIGRATION_PLAN.md` §4 **"Lean mode"**: architect (opus, ≤120-line note) → ≤3 feature-implementers (sonnet) → l10n-porter (haiku) → build iOS + macOS only, filtered output → rules-checker (haiku) → quran-reviewer (opus, one pass) → commit. **No tests, no screenshots, no test-porter or ui-test-writer.** Saad tests from each note's checklist.

Decisions already made for M5.2: the session-only Continue reading bar stays until M6; a bare number is a surah in the public build; the tafsir renderer stays where M5.2 put it, and M5.3 uses it.

| Task | What |
|---|---|
| **M5.2a** (small fix: no architect) | At accessibility text sizes the Library rows (surah, juz, hizb) stack vertically: number, names, details. No word breaks mid-word ("Mecca/n"). Commit body also records M5.2's missing `Agents:` line as it ran. Skip the screenshot-tooling fix for now. |
| **M5.3** | Ayah panel: translation + tafsir (using `TafsirTextView`), sheet on iPhone, inspector on iPad/Mac; pack picker; copy/share with the reference, original text only. |
| **M5.4** | Separated mode: one surah at a time, translation/tafsir inline per settings, "Next surah" at the end, position restore, Amiri option. |
| **M5.5** | Search: query, results with Mushaf-style highlighting, opening the ayah in the current mode; debounce + cancellation. Note the السماوات highlight gap if not fixed. |
| **M5.6** | Settings: Quran section (reader settings as in Mushaf, Translations & Tafsir choices, Sources/licences); in-reader settings sheet; Mac keeps the spread, one page under ~18 pt. Writes only the keys the user chose. |
| **M5.7** | Deferred: automated UI flows and screenshots wait until Saad turns lean mode off. Only do: old routes and `RecentActivity` rows open the right ayah (code, no tests). |

Stop after each task's commit **only if** the reviewer left a Blocking item you couldn't fix or a decision for Saad; otherwise continue to the next task. Stop after M5.7 regardless.

**Stop report (short):** per task, the commit hash, one line on what changed, and the `Agents:` line. Then decisions for Saad (numbered, with your recommendation), new Arabic to review, and **one combined manual test checklist** for M5.2a-M5.7 grouped by device (iPhone, iPad, Mac) and data mode (full / public).
