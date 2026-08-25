//
//  AppBreakpoint.swift
//  ThawabForGod
//

import Foundation

/// Where the layout changes, and by how much.
///
/// **Width, not size class.** The size class answers one question — tab bar or sidebar — and the
/// design asks four more that it cannot: whether two cards may pair, whether a list has become a
/// grid, how many columns that grid has, and whether the accessibility text size has collapsed it
/// back to one. An iPad in a half-width Split View and an iPhone 17 Pro Max are both "compact"
/// and want different answers; a Mac window dragged from 700 to 1200 points never changes size
/// class at all.
///
/// So the thresholds live here as numbers, the per-surface decisions live here as functions, and
/// the views measure themselves. That is also what makes every one of these rules testable
/// without a screen — which matters more than usual, because a breakpoint is exactly the kind of
/// thing that is verified once by hand on one device and then quietly drifts.
///
/// **The accessibility text size outranks every width.** At AX3 and beyond a grid becomes a
/// single column at any width, because two columns of enormous text is two columns of truncation.
/// Every function here takes that as its second argument rather than leaving each caller to
/// remember it.
nonisolated enum AppBreakpoint {

    // MARK: The thresholds

    /// Cards may sit two-up — but the tab bar stays. A sidebar needs more room than a pair of
    /// cards does, which is why these are two numbers and not one. Below it every card is full
    /// width and nothing pairs.
    static let cardsPair: CGFloat = 480

    /// The sidebar replaces the tab bar, and the hadith drill-down loses a level to it.
    static let sidebar: CGFloat = 640

    /// Lists become grids and the Home stack becomes a board.
    static let grids: CGFloat = 700

    /// A grid adds a column rather than growing its cells any further.
    static let fourColumn: CGFloat = 1100

    // MARK: What each surface does with them

    /// Home's card stack, as a number of columns.
    ///
    /// The next-prayer hero is not in this count — it spans the board whatever the width, because
    /// it is the reason the screen is open and a countdown in a half-width column is a countdown
    /// nobody can read across a room.
    static func homeBoardColumns(width: CGFloat, isAccessibilitySize: Bool) -> Int {
        guard !isAccessibilitySize else { return 1 }
        return width >= grids ? 2 : 1
    }

    /// Whether Home is in its middle arrangement: still one column, but with the short cards
    /// paired.
    ///
    /// **A tier of its own, not a smaller board**, and the distinction is the design's. At
    /// `grids` the whole stack becomes two columns and every card takes half the width. Between
    /// `cardsPair` and `grids` there is not room for that — a phone in landscape is 480-odd
    /// points wide, and a list of sentences in 240 of them is a column of truncation — but there
    /// *is* room for the two short cards to sit side by side instead of one above the other.
    ///
    /// Which cards those are is not this function's business; see `HomeSectionKind.canPair`,
    /// because only a section knows its own shape.
    static func homeCardsPair(width: CGFloat, isAccessibilitySize: Bool) -> Bool {
        guard !isAccessibilitySize else { return false }

        return width >= cardsPair && width < grids
    }

    /// The Quran's chapter list, as a number of columns.
    ///
    /// Three at iPad width and four past `fourColumn` — the design is explicit that the fourth
    /// column arrives *instead of* the cells growing, because a chapter cell past about 260pt is
    /// a name and a number with a hand's width of nothing between them.
    static func chapterGridColumns(width: CGFloat, isAccessibilitySize: Bool) -> Int {
        guard !isAccessibilitySize else { return 1 }

        if width >= fourColumn { return 4 }
        if width >= grids { return 3 }
        return 1
    }

    /// The narrowest a chapter cell may be, which is what stops the three-column grid forming a
    /// column early on a window that is wide enough for the count but not for the cells.
    static let chapterCellMinimum: CGFloat = 200

    /// The day's six markers, as a number of columns.
    ///
    /// Six across, or 3 × 2 at an accessibility size — the one grid in the app whose collapsed
    /// form is still a grid, because three columns of two is a shape a reader can still scan as
    /// a day where six stacked rows would be a list.
    static func dayStripColumns(isAccessibilitySize: Bool) -> Int {
        isAccessibilitySize ? 3 : 6
    }

    /// The widest a column of scripture may be: about sixty to seventy-five Latin characters,
    /// centred in whatever space is left over.
    ///
    /// A cap rather than a fraction of the window. A reader dragged to full screen on a 27-inch
    /// display does not want a line of Arabic a foot long — the eye loses the start of the line
    /// on the way back from the end of it, which is the one failure a reading app cannot afford.
    static let readingMeasure: CGFloat = 640

    /// The widest the ordinary card stack goes before it starts centring instead of stretching.
    /// Below the board's threshold this is what keeps a single column from becoming a very wide
    /// single column.
    static let contentMeasure: CGFloat = 560

    // MARK: Targets

    /// The smallest a control may be drawn.
    ///
    /// Two numbers because they are two different instruments: a fingertip needs 44pt and a
    /// cursor needs 28, and holding the Mac to the phone's number is how a settings window ends
    /// up three screens long.
    #if os(macOS)
    static let minimumTapTarget: CGFloat = 28
    #else
    static let minimumTapTarget: CGFloat = 44
    #endif
}
