//
//  AppBreakpointDuoTests.swift
//  ThawabForGodTests
//

import CoreGraphics // CGFloat; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

/// The reflow rules at the iPhone Duo's two geometries.
///
/// A suite of its own rather than more cases in `AppBreakpointTests`, because these widths are not
/// arbitrary probes of the thresholds — they are two specific screens, and what is being pinned is
/// *which tier each screen lands in*. When the numbers below are corrected, the failures should
/// read as "the Duo moved tier", not as "a breakpoint changed".
///
/// **The point dimensions are derived, not published.** Apple publishes the Duo's pixel
/// resolutions and densities — 1398 × 2034 at 460 ppi closed, 1878 × 2670 at 430 ppi open — but
/// not the rendered point sizes, so the values here are those resolutions at the @3x scale every
/// current iPhone uses. Secondary sources agree on the pair 626 / 890 for the inner display and
/// disagree about which of the two is the width. Both orientations are therefore pinned, and
/// neither is asserted to be *the* portrait one.
///
/// What is not derived is the part that actually drives the app: Apple's own "Prepare your app for
/// iPhone Duo" states that the inner display is **regular in both size classes** and that it does
/// not honour `supportedInterfaceOrientations`. That is what sends `MainInterfaceView` to
/// `MainSplitView`, and it holds whichever way round the width is.
struct AppBreakpointDuoTests {

    // MARK: The two screens

    /// The cover display, closed: 1398 × 2034 at @3x.
    static let coverWidth: CGFloat = 466

    /// The inner display, open: 1878 × 2670 at @3x, in both readings of which edge is the width.
    static let innerShortEdge: CGFloat = 626
    static let innerLongEdge: CGFloat = 890

    /// What the sidebar asks for in `MainSplitView`, which is what the detail column does *not*
    /// get. `min: 180, ideal: 220, max: 320` — the ideal is the honest figure to plan against.
    static let sidebarIdeal: CGFloat = 220

    // MARK: Closed

    /// Closed, the Duo is an ordinary phone: one column, nothing paired.
    ///
    /// **This is the app's narrowest margin anywhere**, and the reason it is pinned rather than
    /// left to be obvious. The cover display is 466pt and `cardsPair` is 480 — fourteen points
    /// apart. A correction to either number flips the entire closed-state layout of Home from a
    /// stack to a stack with paired cards, and fourteen points is well inside the error bar on a
    /// dimension nobody has published.
    @Test func theCoverDisplayIsAStackAndStaysJustInsideTheStackTier() {
        #expect(!AppBreakpoint.homeCardsPair(width: Self.coverWidth, isAccessibilitySize: false))
        #expect(AppBreakpoint.homeBoardColumns(width: Self.coverWidth, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.chapterGridColumns(width: Self.coverWidth, isAccessibilitySize: false) == 1)

        // Named so the margin fails loudly rather than silently absorbing a revision.
        #expect(Self.coverWidth < AppBreakpoint.cardsPair)
        #expect(AppBreakpoint.cardsPair - Self.coverWidth == 14)
    }

    // MARK: Open

    /// Open, the *window* is wide enough for the board and the three-column grid — on the long
    /// reading of the inner display, and on neither reading for the short one.
    ///
    /// This is the window, not the content. What Home and the chapter list actually measure is the
    /// detail column, which is the next test and is a different tier.
    @Test func theOpenWindowClearsTheGridsThresholdOnlyOnItsLongEdge() {
        #expect(AppBreakpoint.homeBoardColumns(width: Self.innerLongEdge, isAccessibilitySize: false) == 2)
        #expect(AppBreakpoint.chapterGridColumns(width: Self.innerLongEdge, isAccessibilitySize: false) == 3)

        #expect(AppBreakpoint.homeBoardColumns(width: Self.innerShortEdge, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.chapterGridColumns(width: Self.innerShortEdge, isAccessibilitySize: false) == 1)
    }

    /// **The sidebar spends the width the grids needed.** Unfolding puts the app in a regular size
    /// class, so `MainInterfaceView` draws `MainSplitView` and the sidebar takes its 220 points
    /// off the front — which drops the detail column back below `grids` on *both* readings of the
    /// inner display.
    ///
    /// So opening the Duo does not give the Quran's chapter list a grid, and does not turn Home
    /// into a board. It buys the paired-card tier on the long reading and nothing at all on the
    /// short one. That is a design question rather than a defect — the sidebar is itself what the
    /// extra width bought — but it is the kind of thing that should be a failing test the day
    /// somebody decides otherwise, not a surprise on a device.
    @Test func theDetailColumnFallsBackBelowTheGridsThresholdOnBothReadings() {
        let long = Self.innerLongEdge - Self.sidebarIdeal    // 670
        let short = Self.innerShortEdge - Self.sidebarIdeal  // 406

        #expect(AppBreakpoint.chapterGridColumns(width: long, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.homeBoardColumns(width: long, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.homeCardsPair(width: long, isAccessibilitySize: false))

        #expect(AppBreakpoint.chapterGridColumns(width: short, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.homeBoardColumns(width: short, isAccessibilitySize: false) == 1)
        #expect(!AppBreakpoint.homeCardsPair(width: short, isAccessibilitySize: false))
    }

    // MARK: The threshold the app documents and does not read

    /// `AppBreakpoint.sidebar` says "the sidebar replaces the tab bar" at 640 points. Nothing
    /// reads it — the decision is `horizontalSizeClass == .compact` in `MainInterfaceView`, and
    /// the constant survives only in the ordering assertion in `AppBreakpointTests`.
    ///
    /// That has been harmless because on every device shipped to date a regular horizontal size
    /// class has meant something like 768 points or more, comfortably past 640. **The Duo's inner
    /// display is the first case where the two can disagree**: Apple documents it as regular in
    /// both size classes, and on the short reading of its geometry that is a regular size class at
    /// 626 points — inside the app's own "too narrow for a sidebar" band, with a sidebar drawn
    /// across it anyway.
    ///
    /// This test pins the disagreement rather than resolving it, because resolving it means either
    /// deleting a documented threshold or measuring width at the app root, and neither is worth
    /// doing against a dimension that is still derived. When the Duo simulator in Xcode 27.1
    /// settles the real width, this test is where the answer belongs.
    @Test func theSidebarThresholdAndTheSizeClassCanDisagreeOnTheInnerDisplay() {
        // The constant still claims a rule.
        #expect(AppBreakpoint.sidebar == 640)

        // And the short reading of the inner display sits under it, while still being a width at
        // which the app will draw a sidebar, because the size class says regular.
        #expect(Self.innerShortEdge < AppBreakpoint.sidebar)
        #expect(Self.innerLongEdge > AppBreakpoint.sidebar)
    }

    // MARK: The rule that outranks the others, here too

    /// An accessibility text size collapses both screens to one column, as it does every width.
    /// The three widths are the constants above, spelled out because an attribute argument is
    /// not a context that can see the type's own members.
    @Test(arguments: [466.0, 626.0, 890.0])
    func accessibilityTextCollapsesBothDuoScreens(width: CGFloat) {
        #expect(AppBreakpoint.homeBoardColumns(width: width, isAccessibilitySize: true) == 1)
        #expect(AppBreakpoint.chapterGridColumns(width: width, isAccessibilitySize: true) == 1)
        #expect(!AppBreakpoint.homeCardsPair(width: width, isAccessibilitySize: true))
    }
}
