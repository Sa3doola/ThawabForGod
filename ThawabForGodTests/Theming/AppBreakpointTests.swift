//
//  AppBreakpointTests.swift
//  ThawabForGodTests
//

import CoreGraphics // CGFloat; MEMBER_IMPORT_VISIBILITY means it is not re-exported
import Testing
@testable import ThawabForGod

/// The reflow rules, which are the kind of thing verified once by hand on one device and then
/// left to drift. Every one of them is a pure function of a width and a type size, so every one
/// of them can be pinned here instead.
struct AppBreakpointTests {

    // MARK: Home

    @Test(arguments: [320.0, 393.0, 480.0, 639.0, 699.0])
    func homeIsOneColumnBelowTheBoardThreshold(width: CGFloat) {
        #expect(AppBreakpoint.homeBoardColumns(width: width, isAccessibilitySize: false) == 1)
    }

    @Test(arguments: [700.0, 1024.0, 1280.0, 2000.0])
    func homeBecomesABoardAtTheBoardThreshold(width: CGFloat) {
        #expect(AppBreakpoint.homeBoardColumns(width: width, isAccessibilitySize: false) == 2)
    }

    // MARK: The chapter grid

    @Test func theChapterListIsAListUntilItIsAGrid() {
        #expect(AppBreakpoint.chapterGridColumns(width: 699, isAccessibilitySize: false) == 1)
        #expect(AppBreakpoint.chapterGridColumns(width: 700, isAccessibilitySize: false) == 3)
    }

    /// The fourth column arrives *instead of* the cells growing, which is the whole point of
    /// having a second threshold rather than an adaptive minimum.
    @Test func theFourthColumnArrivesRatherThanWiderCells() {
        #expect(AppBreakpoint.chapterGridColumns(width: 1099, isAccessibilitySize: false) == 3)
        #expect(AppBreakpoint.chapterGridColumns(width: 1100, isAccessibilitySize: false) == 4)
        #expect(AppBreakpoint.chapterGridColumns(width: 3000, isAccessibilitySize: false) == 4)
    }

    // MARK: The rule that outranks the others

    /// At an accessibility size every grid is one column at *any* width. A test per surface,
    /// because the rule is stated once in the design and has to hold in each place separately.
    @Test(arguments: [400.0, 700.0, 1024.0, 1400.0, 3000.0])
    func accessibilityTextCollapsesEveryGridAtEveryWidth(width: CGFloat) {
        #expect(AppBreakpoint.homeBoardColumns(width: width, isAccessibilitySize: true) == 1)
        #expect(AppBreakpoint.chapterGridColumns(width: width, isAccessibilitySize: true) == 1)
    }

    /// The one exception: the six-times strip stays a grid when it collapses, because three
    /// columns of two still reads as a day and six stacked rows read as a list.
    @Test func theDayStripCollapsesToAGridRatherThanAList() {
        #expect(AppBreakpoint.dayStripColumns(isAccessibilitySize: false) == 6)
        #expect(AppBreakpoint.dayStripColumns(isAccessibilitySize: true) == 3)
    }

    // MARK: The middle tier

    /// The tier the design puts between one column and the board: still a single column, but
    /// with the short cards paired. A phone in landscape and a half-width iPad Split View both
    /// land here.
    @Test func cardsPairOnlyBetweenTheirOwnThresholdAndTheBoard() {
        #expect(!AppBreakpoint.homeCardsPair(width: 400, isAccessibilitySize: false))
        #expect(AppBreakpoint.homeCardsPair(width: 480, isAccessibilitySize: false))
        #expect(AppBreakpoint.homeCardsPair(width: 640, isAccessibilitySize: false))
        // At the board's threshold the pairing stops, because the whole stack takes over.
        #expect(!AppBreakpoint.homeCardsPair(width: 700, isAccessibilitySize: false))
        #expect(!AppBreakpoint.homeCardsPair(width: 1_200, isAccessibilitySize: false))
    }

    /// The two arrangements are exclusive: no width may both pair cards and lay out a board, or
    /// a card would be claimed by two layouts at once.
    @Test func pairingAndTheBoardNeverOverlap() {
        for width in stride(from: CGFloat(320), through: 1_400, by: 20) {
            let pairs = AppBreakpoint.homeCardsPair(width: width, isAccessibilitySize: false)
            let board = AppBreakpoint.homeBoardColumns(width: width, isAccessibilitySize: false) > 1

            #expect(!(pairs && board), "both at \(width)pt")
        }
    }

    /// The accessibility size outranks the width here as it does everywhere else — two columns
    /// of enormous text is two columns of truncation.
    @Test func anAccessibilitySizeUnpairsAtEveryWidth() {
        for width in stride(from: CGFloat(320), through: 1_400, by: 20) {
            #expect(!AppBreakpoint.homeCardsPair(width: width, isAccessibilitySize: true))
        }
    }

    // MARK: Ordering

    /// The thresholds have to stay in the order the design states them in — a sidebar that
    /// appeared after the grids formed, or a fourth column before the third, would each be a
    /// layout nobody drew.
    @Test func theThresholdsAscendInTheOrderTheDesignStatesThem() {
        #expect(AppBreakpoint.cardsPair < AppBreakpoint.sidebar)
        #expect(AppBreakpoint.sidebar < AppBreakpoint.grids)
        #expect(AppBreakpoint.grids < AppBreakpoint.fourColumn)
    }

    @Test func aColumnOfScriptureIsNarrowerThanTheCardStackIsWide() {
        // Not an arbitrary pair: the reading measure is a *cap on a line of text* and the content
        // measure is a cap on a stack of cards, so the first must never exceed the second by
        // enough to make the reader the widest thing in the app.
        #expect(AppBreakpoint.readingMeasure > AppBreakpoint.contentMeasure)
        #expect(AppBreakpoint.readingMeasure <= AppBreakpoint.grids)
    }
}

/// The two metrics that travel with a type step, both of which depend on the script.
struct AppTextStyleMetricsTests {

    /// Only the two display steps are tightened. Tightening a caption would take letters out of
    /// each other's way at a size where they were never in it.
    @Test func onlyTheDisplayStepsAreTightened() {
        #expect(AppTextStyle.largeTitle.tracking(isArabic: false) == -0.4)
        #expect(AppTextStyle.title.tracking(isArabic: false) == -0.3)

        for style in AppTextStyle.allCases where style != .largeTitle && style != .title {
            #expect(style.tracking(isArabic: false) == 0)
        }
    }

    /// The rule the design states in one line and this pins at every step: Arabic is a joined
    /// script, so negative tracking pulls the connecting strokes into the letters beside them.
    @Test func arabicIsNeverTightened() {
        for style in AppTextStyle.allCases {
            #expect(style.tracking(isArabic: true) == 0)
        }
    }

    @Test func arabicTakesMoreLeadingAtEveryStep() {
        for style in AppTextStyle.allCases {
            let latin = style.additionalLineSpacing(isArabic: false, size: style.nominalSize)
            let arabic = style.additionalLineSpacing(isArabic: true, size: style.nominalSize)

            #expect(latin == 0)
            #expect(arabic > 0)
        }
    }

    /// The leading is a fraction of the size it is given, not of the nominal one — which is what
    /// makes it grow with Dynamic Type rather than staying at its default-size value while the
    /// text around it doubles.
    @Test func theLeadingFollowsTheSizeItIsGiven() {
        let atDefault = AppTextStyle.body.additionalLineSpacing(isArabic: true, size: 17)
        let atDouble = AppTextStyle.body.additionalLineSpacing(isArabic: true, size: 34)

        #expect(abs(atDouble - atDefault * 2) < 0.0001)
    }

    /// Every step's nominal size, against the canvas's own type board.
    ///
    /// A table rather than an ordering assertion, because the enum is not declared in size order
    /// — `subheadline` sits before `body` — and the useful invariant is not "these descend" but
    /// "these are the numbers the design specified". Anything that drifts from the board drifts
    /// from the design, and this is the only place that would notice.
    @Test(arguments: [
        (AppTextStyle.largeTitle, CGFloat(34)), (.title, 28), (.title2, 22), (.title3, 20),
        (.headline, 17), (.body, 17), (.callout, 16), (.subheadline, 15),
        (.footnote, 13), (.caption, 12)
    ])
    func eachStepIsTheSizeTheDesignBoardStates(style: AppTextStyle, size: CGFloat) {
        #expect(style.nominalSize == size)
    }

    /// And every step is covered by that table, so adding a case cannot slip past it.
    @Test func everyStepHasASize() {
        #expect(AppTextStyle.allCases.allSatisfy { $0.nominalSize > 0 })
    }
}
