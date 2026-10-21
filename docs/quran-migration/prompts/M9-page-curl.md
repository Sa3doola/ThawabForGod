# M9: book-style page turning (page curl), no tests

New session, `/model sonnet`. Lean pipeline: quran-architect (opus, ≤120-line note `design/M9.md`) → ≤3 feature-implementers (sonnet) → l10n-porter (haiku) → build iOS + macOS only → rules-checker (haiku) → quran-reviewer (opus, one pass) → commit with `Agents:` / `Tests: not run`. **No test runs, no screenshots.** Saad tests.

## What
Turning pages in the Mushaf reader looks like a real book: the page curls.

- **iOS/iPadOS:** a `UIPageViewController` with `.pageCurl`, wrapped for SwiftUI, replacing the scroll pager in `Features/Quran/Mushaf/MushafPagerView.swift` (keep `MushafPagerStep` maths and the one-page-at-a-time guard from B3).
  - Arabic book: the spine is on the **right**; the next page comes from the **left** edge (swipe left-to-right to go forward), whatever the app language.
  - Single page: `spineLocation .max` (right). Spread (iPad landscape, Duo unfolded, wide windows): `.mid` with two pages, odd page on the right as printed. Keep the existing spread/single rules and fold geometry.
  - **Swipe only:** remove `UIPageViewController`'s tap gesture recognizers (B3: taps never turn pages). Taps keep selecting ayahs / toggling chrome.
  - Keyboard/menu paging (M7.2, B6) and Go to page animate with the curl (jumps of more than one page set the page without animation).
  - Each page is a `UIHostingController` of the existing page view; reuse at most 3 controllers (previous, current, next); respect the `FontPackStore` window. No extra memory per page turn.
  - VoiceOver: page turn with the three-finger scroll as today; announce the new page.
- **macOS:** no system curl. Keep paging with a short slide in reading direction (or a cross-fade), as today. No `#if os` outside platform glue.
- **Setting:** Reading Options → "Page turn": **Book (curl)** default on iPhone/iPad, **Slide** (the current scroll pager) as the alternative. One new `SettingsKey`, written only when the user chooses. ar + en strings.
- Reduce Motion on → use Slide automatically.
- Unchanged: separated mode, immersive mode, the ayah side panel/sheet, tabletop bottom panel, reading position saving, selection highlight.

## Saad's checklist (put it at the end of design/M9.md)
iPhone portrait/landscape, iPad portrait + landscape spread, Duo folded/unfolded/tabletop, Mac: swipe forward/back, curl direction (right-to-left book), taps on words never turn, keyboard ← → and Go to page, page 1 and 604 edges, spread pairs correct (2-3, 50-51), memory steady paging 1→50, setting switch Book ↔ Slide keeps the page, Reduce Motion.

Stop after the commit.
