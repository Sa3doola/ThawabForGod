# M7: platforms and widgets, lean mode

New session, `/model sonnet`. Follow `QURAN_MIGRATION_PLAN.md` §4 "Lean mode" (architect ≤120 lines → ≤3 implementers → l10n-porter → build iOS + macOS, filtered → rules-checker → quran-reviewer, one pass → commit). No test runs, no screenshots; Saad tests from each note's checklist. Traps: T5, T11, T12 in §2.

Commit bodies: keep 3-8 bullet lines of what changed and a "Fixed in review" list (M6.3/M6.4 had only the Agents line), then `Agents:` and `Tests:`.

Saad's answers for M6.4: Continue reading resumes without selecting an ayah, the chip selects; keep both the Home card and the chip; 1 s debounce and 10 recents. All as designed.

| Task | What |
|---|---|
| **M7.1** | iPad gets the ayah panel inspector back (reverted to a sheet in 647f769 because `.inspector` on the pushed reader pops it). Attach the inspector at the split view's detail column / the Quran `NavigationStack` root, driven by `QuranCoordinator`'s panel state; regular width landscape → inspector, compact / portrait → sheet (M5.3 rules). Mac unchanged. The note editor stays a sheet. Reproduce the original pop on an iPad simulator once before and after (the only run allowed in this milestone). |
| **M7.2** | Keyboard and Mac menu (T11): a Quran menu whose commands are active **only while the Quran section is focused** (`focusedSceneValue` / `FocusedValues`, never global): ⌘F search, ⌘G go to (Library field), ⌘D bookmark the selected/first ayah, ⌥⌘I panel, ⌘[ / ⌘] previous/next surah, theme cycle, and arrow / space paging in the Mushaf (RTL: ← is the next page). Same shortcuts on iPad with a hardware keyboard (`.keyboardShortcut`, discoverable in the ⌘ overlay). Port Mushaf's mapping and labels; ar + en. |
| **M7.3** | iPhone landscape rules and the Duo (T12): port Mushaf's landscape behaviour (one page fit to width, scrolling, or separated) and the Duo panel/tabletop layouts onto `Core/Layout/FoldGeometry`. Adhkar's `ArrangementView` untouched. `#if os` only in platform glue. |
| **M7.4** | Widget data (T5): `DeepLink` gains `quranVerse` and `quranPage` (additive; old links still resolve; `quranPage` in the public build resolves to that page's first ayah through the full map if present, otherwise the Quran tab root, never a wrong place). The app publishes to `SharedDefaults`: the reading position (surah name, `s:v`, page if any) and today's ayah (text exactly as stored, reference, the first enabled translation if any) from `ayah-of-the-day.txt` via the existing daily rule. Copy the Hafs face into the App Group container once per app version for the widget to register. Republish on position change (debounced, the M6.4 chain), on day change and on pack change; `WidgetCenter.reloadTimelines(ofKind:)` only for the two new kinds. |
| **M7.5** | Widgets in `NoorWidgets`: **Continue Reading** (small, medium, lock-screen rectangular) and **Ayah of the Day** (medium, large, lock-screen rectangular), timelines to the next midnight, Arabic in the registered Hafs face (system face never used for Quran text; if registration fails, show the reference only). Taps use the new deep links. Existing prayer widget kinds untouched. Strings ar + en. `ayah-of-the-day.txt` is now final (reviewed 2026-10-18; 65:2-3 replaced by 25:63): regenerate its built output with QuranBuilder (both profiles) in M7.4 and commit the source with it; don't edit its entries. |

Stop only for a Blocking item you can't fix or a decision for Saad; stop after M7.5 regardless.

**Stop report (short):** per task commit hash, one line and the `Agents:` line; decisions for Saad; new Arabic to review; one combined M7 manual checklist grouped by iPhone, iPhone landscape, Duo, iPad (keyboard), Mac, widgets, in full and public data modes.
