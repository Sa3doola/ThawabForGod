# Contributing

Noor is meant to double as a clean, well-documented reference for native
SwiftUI development, so contributions that keep it legible for someone
reading the source to learn from are as welcome as ones that ship a feature.

## Before you start

- Read [`ARCHITECTURE.md`](ARCHITECTURE.md) for the shape of the codebase and
  [`CLAUDE.md`](CLAUDE.md) for the folder-by-folder conventions — dependency
  direction, where a new file belongs, localization and theming rules. Both
  are living documents; if something in the code contradicts them, that's
  worth a PR on its own.
- For anything more than a small fix, open an issue first describing what
  you'd like to change. It saves both of us from a large PR that turns out to
  need a different shape.
- Check [`Islamic_App_Architecture_Plan.md`](Islamic_App_Architecture_Plan.md)
  for where the project currently is in its phasing — Phase 1 (the core app)
  vs. Phase 2 (Quran) vs. Phase 3 (Hadith + memorization) — so a contribution
  lands in the phase it belongs to.

## Requirements

- Xcode with SDKs for iOS/iPadOS 17.0+ and macOS 15.0+ (the project's
  deployment targets — don't reach for an API newer than that).
- No CocoaPods, no external linter/formatter. Two SPM dependencies only:
  [Adhan](https://github.com/batoulapps/adhan-swift) and
  [GRDB](https://github.com/groue/GRDB.swift). If a change genuinely needs a
  new one, add it through Xcode's **File → Add Package Dependencies…** UI —
  there is no supported way to hand-edit `project.pbxproj` for this, and pull
  requests that do will need to be redone through Xcode.

## Building and testing

```bash
# iOS Simulator build
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# macOS build — both platforms must stay green, not just the simulator
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=macOS' -quiet

# Full test suite
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

# The same suite on the Mac. Worth running when a change touches anything
# under a #if os(macOS) — the menu bar, the login item — because the iOS
# destination compiles none of it.
xcodebuild test -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=macOS' -quiet

# Swift 6 strict-concurrency check, without changing the project's language
# mode — catches data-race problems the normal build won't
xcodebuild build -scheme ThawabForGod -project ThawabForGod.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_VERSION=6.0 -quiet
```

**All five must be clean — warnings count as failures.** Run them before
opening a PR; CI runs the first three and will fail the same way.

A note on exit codes: `grep`ping the output for `error:` is not enough. A
failure to *sign* an embedded extension reports as `Command CodeSign failed`
with no such prefix, so check `$?` — a stale `.appex` from before the widget
target supported macOS produces exactly that, and `xcodebuild clean` is the
fix.

One caveat on the fourth: the `SWIFT_VERSION=6.0` check currently crashes the
compiler in IRGen rather than reporting a diagnostic, and does so on a clean
checkout of older commits too — a toolchain bug, not a problem in this source.
Until the toolchain moves, its failure tells you nothing. It is the one command
CI does not run; see [CI.md](CI.md).

## Code conventions, briefly

The full list is in `CLAUDE.md`; the ones that come up most often:

- **Constructor injection only**, wired in `AppContainer`. No singletons for
  app logic.
- **`@Observable`**, not `ObservableObject`/`@Published`, in new code.
- Every repository or service is a **Domain protocol + a Data implementation**
  — never a concrete type reached for directly outside `AppContainer`.
- **No literal colors or fonts.** Go through `@Environment(\.theme)` and
  `.appFont(_:weight:)`.
- **No hardcoded user-facing strings.** Add an `L10nKey` case and both the
  Arabic and English translation in `Resources/Localizable.xcstrings` in the
  same PR — there's a test that fails if a key is missing either language.
- **No `Text(date, style:)` or raw string interpolation for numbers.** Route
  through `LocalizationManager` so the digit system (Arabic-Indic vs. Latin)
  is respected everywhere.
- Keep `body` small; extract a subview past ~60 lines or wherever it's
  reused.
- Write new unit tests with **Swift Testing** (`import Testing`, `@Test`,
  `#expect`), not XCTest — that's reserved for the UI test target.

## Changing the bundled corpus

The adhkar and 99-names data in `ThawabForGod/Resources/Corpus/corpus.sqlite`
is generated, never hand-edited — see
[`ThawabForGod/Resources/Corpus/README.md`](ThawabForGod/Resources/Corpus/README.md)
for the build step, the sourcing notes, and — importantly — the standing
warning that none of this content has had a full scholarly verification
pass. A correction to the text itself belongs upstream or in
`Tools/CorpusBuilder/`, followed by re-running the build script; a PR that
edits `corpus.sqlite`'s bytes directly will be asked to redo it that way.

## Commit and PR expectations

- Keep commits focused; a PR that touches one slice (a feature, a Core
  subsystem) is easier to review than one that touches several.
- Describe *why*, not just *what* — this codebase's own comments lean that
  way, and a PR description that does too is easier to review against the
  existing conventions.
- Mirror every new screen for RTL (Arabic) as you build it, not as a
  follow-up — flipping `\.layoutDirection` on a live view has real gotchas
  documented in `CLAUDE.md`'s localization section, which is exactly why the
  project's approach is to let the system apply it at launch rather than
  switch it at runtime.

## License

By contributing, you agree your contribution is licensed under this
project's [MIT license](LICENSE). If your change bundles or references
third-party religious text data, its license must be compatible and must be
documented the way the existing corpus sources are.
