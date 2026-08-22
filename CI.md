# Continuous integration

Noor's CI is **Xcode Cloud**. This file records what the repository provides,
what has to be created in App Store Connect by hand, and why it was set up this
way.

## Why Xcode Cloud and not GitHub Actions

The plan called for "CI running tests + a build for each platform". Both would
do that. Xcode Cloud wins here on three counts:

- **No runner to maintain.** The project is Xcode-shaped — one scheme, two SPM
  dependencies, no CocoaPods, no code generation, no linter. A GitHub Actions
  workflow would spend most of its lines pinning an Xcode version and selecting
  a simulator runtime, which is exactly the drift that makes a green CI stop
  meaning anything.
- **The macOS build is a first-class destination**, not a second job on a
  scarce runner. This project's rule is that *both* platforms stay green, and
  Xcode Cloud runs them in parallel.
- **TestFlight is one step further on**, which matters for a V1 that is meant to
  reach the App Store.

The cost is a hard requirement: **Apple Developer Program membership**. Xcode
Cloud is not available without one. Membership includes 25 compute hours per
month, and a full run of this project's three actions is on the order of ten
minutes — so the included allowance is not a constraint at this project's pace.
Paid tiers start at 100 hours for US$49.99/month.

> GitHub Actions is free for public repositories and this repo is public, so it
> remains a reasonable fallback if the membership lapses. Nothing in the repo is
> Xcode-Cloud-specific — the same `xcodebuild` commands in `CONTRIBUTING.md` are
> what any runner would execute.

## What the repository already provides

Two things had to be committed before *any* CI could run, and both are done:

1. **A shared scheme** — `ThawabForGod.xcodeproj/xcshareddata/xcschemes/ThawabForGod.xcscheme`.
   Xcode autocreates schemes per-user under `xcuserdata/`, which is gitignored,
   so before this the repository contained no scheme at all and a fresh clone
   had nothing for a build service to select. The shared scheme builds the app
   and marks **both** test targets — `ThawabForGodTests` (Swift Testing) and
   `ThawabForGodUITests` (XCTest) — as testable.

2. **`Package.resolved`, no longer gitignored** —
   `ThawabForGod.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
   It pins Adhan and GRDB to exact revisions. Without it a cloud runner resolves
   both afresh against `upToNextMajor`, so CI would be testing a different build
   of the app than the one that passed locally — and a dependency's own
   regression would surface as this project's test failure.

There is deliberately **no `ci_scripts/` directory**. Xcode Cloud looks for
`ci_post_clone.sh` and friends at the repository root, and this project needs
none of them: no dependency manager to bootstrap, no generated sources, and the
four corpus SQLite files are committed to git directly rather than through LFS,
so a plain clone is a complete checkout. Add one only when that stops being
true.

## The workflow to create

Xcode Cloud workflows live in **App Store Connect**, not in the repository, so
this part cannot be committed — it has to be created once, by hand, by someone
with the membership. In Xcode: **Product → Xcode Cloud → Create Workflow**, or
in App Store Connect under the app's **Xcode Cloud** tab. Xcode will ask to
install the Xcode Cloud GitHub app on `Sa3doola/ThawabForGod` the first time.

Create one workflow, **"Build and Test"**:

| Setting | Value |
|---|---|
| Start condition | Branch changes — `main`, and pull request changes targeting `main` |
| Environment | Latest release Xcode, latest macOS |
| Action 1 | **Build** — platform **macOS** |
| Action 2 | **Test** — platform **iOS Simulator**, scheme `ThawabForGod`, destination iPhone (latest) |
| Action 3 | **Test** — platform **iOS Simulator**, destination iPad (latest) |
| Post-action | None yet |

Three actions rather than two because the iPad destination is the one that
exercises `MainSplitView`; the iPhone destination exercises `MainTabView`. They
are different arrangements of the same sections — see `MainInterfaceView` — and
a suite that only ever ran on a phone would never build the sidebar at all.

The macOS **Build** action rather than a Test action is deliberate: the unit
tests are platform-agnostic, and what the Mac build catches is the thing that
actually breaks there — a `#if os(macOS)` branch that stopped compiling.

## Signing, and the one thing CI needs that a checkout does not carry

Both targets declare an **App Group** (`group.com.Sa3dola.ThawabForGod`) in their
entitlements, which means both need a provisioning profile that includes it.
Automatic signing usually creates the identifier on first local build, but a
clean CI machine has never run that — so the group has to exist in the Developer
portal, enabled on **both** App IDs (`com.Sa3dola.ThawabForGod` and
`com.Sa3dola.ThawabForGod.NoorWidgets`), or the build fails at the signing step
with an error that reads like a certificate problem and is not one.

Nothing else about the widget needs a workflow change: `NoorWidgetsExtension` is
embedded in the app, so all three actions build it already — including the macOS
one, which is now the cheapest place a widget view using an iOS-only API gets
caught.

## What is deliberately not in the workflow

**The `SWIFT_VERSION=6.0` strict-concurrency check.** `CONTRIBUTING.md` lists it
as a local pre-PR command, and it should stay local: as of this writing it
crashes `swift-frontend` in IRGen rather than reporting a diagnostic, and it does
so on a clean checkout of an older commit too — a toolchain bug, not a problem in
this source. Wiring a known-crashing command into CI would produce a permanently
red badge that everyone learns to ignore. Add the action once the toolchain
moves.

## Keeping this honest

`CONTRIBUTING.md` tells contributors that "CI runs the same commands and will
fail the same way." That is only true while the workflow above matches the
commands in that file. If one changes, change the other.
