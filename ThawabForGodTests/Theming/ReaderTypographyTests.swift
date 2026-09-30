//
//  ReaderTypographyTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

/// The clamping, which is the whole of this type's behaviour.
///
/// Worth its own suite because the values only ever arrive from the settings store, and the store
/// will hand back whatever is in it — a number from an older build whose range was different, one
/// edited by hand in a plist, or a `0` that came from a key that was never really set.
struct ReaderTypographyTests {

    /// The spacing default is zero because it is an *addition* to the face's own leading, and
    /// the face's tuning is the only value right for every face at once.
    @Test func defaultsMatchTheSizeTheReaderStartedFrom() {
        #expect(ReaderTypography.fallback.textSize == 20)
        #expect(ReaderTypography.fallback.lineSpacing == 0)
    }

    @Test func keepsValuesInsideTheRange() {
        let typography = ReaderTypography(textSize: 28, lineSpacing: 6)

        #expect(typography.textSize == 28)
        #expect(typography.lineSpacing == 6)
    }

    @Test(arguments: [
        (0.0, ReaderTypography.textSizeRange.lowerBound),
        (-40.0, ReaderTypography.textSizeRange.lowerBound),
        (400.0, ReaderTypography.textSizeRange.upperBound)
    ])
    func clampsTextSize(_ given: Double, _ expected: Double) {
        #expect(ReaderTypography(textSize: given, lineSpacing: 14).textSize == expected)
    }

    @Test(arguments: [
        (-1.0, ReaderTypography.lineSpacingRange.lowerBound),
        (999.0, ReaderTypography.lineSpacingRange.upperBound)
    ])
    func clampsLineSpacing(_ given: Double, _ expected: Double) {
        #expect(ReaderTypography(textSize: 20, lineSpacing: given).lineSpacing == expected)
    }

    /// Zero leading is a real choice — more verses on a screen — so it must survive the clamp
    /// rather than being read as "unset" and replaced.
    @Test func zeroLineSpacingIsAllowed() {
        #expect(ReaderTypography(textSize: 20, lineSpacing: 0).lineSpacing == 0)
    }

    /// Every comparison against `NaN` is false, so `min`/`max` alone would let it straight
    /// through to a `Font` that cannot lay it out. The infinities go the same way rather than
    /// clamping to the end they point at — see the type's own note on why corruption resolves
    /// small.
    @Test func nonFiniteValuesFallToTheLowerBound() {
        let typography = ReaderTypography(textSize: .nan, lineSpacing: .infinity)

        #expect(typography.textSize == ReaderTypography.textSizeRange.lowerBound)
        #expect(typography.lineSpacing == ReaderTypography.lineSpacingRange.lowerBound)
    }

    @Test func changingOneValueLeavesTheOtherAlone() {
        let typography = ReaderTypography(textSize: 24, lineSpacing: 8)

        #expect(typography.with(textSize: 30) == ReaderTypography(textSize: 30, lineSpacing: 8))
        #expect(typography.with(lineSpacing: 2) == ReaderTypography(textSize: 24, lineSpacing: 2))
    }
}
