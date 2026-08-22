//
//  ReaderTypography.swift
//  ThawabForGod
//

import Foundation

/// How large the scripture is set, and how far apart its lines sit.
///
/// A point size rather than a multiplier on the type scale, which is the one place the reader
/// departs from `AppTextStyle`. Everywhere else in the app a size is the design system's to
/// choose; here it is the reader's, and "one and a half steps larger than title3" is not a thing
/// anybody can hold in their head. Dynamic Type still scales on top of whatever is chosen here —
/// see `ReadingFontModifier`, which is where that is applied.
///
/// Both values are clamped on the way in. The store is the only thing that ever supplies them,
/// and a value that has been hand-edited, migrated from an older build, or corrupted should
/// produce small text rather than a page of unreadably large glyphs.
nonisolated struct ReaderTypography: Equatable, Sendable {

    /// The verse text's size at the default Dynamic Type setting.
    let textSize: Double

    /// Space added between the wrapped lines of one verse.
    let lineSpacing: Double

    /// Roughly "comfortably readable" at the bottom and "one word a line" at the top. Wider than
    /// the app's own type scale on purpose: Arabic script carries diacritics that a reader with
    /// good eyesight may still want enlarged to distinguish.
    static let textSizeRange: ClosedRange<Double> = 18...44
    static let textSizeStep: Double = 2

    /// Zero is allowed — the tightest setting is a legitimate choice for a reader who wants more
    /// verses on screen — and the top is generous, because diacritics above and below the line
    /// are what make Arabic need more leading than Latin at the same size.
    static let lineSpacingRange: ClosedRange<Double> = 0...28
    static let lineSpacingStep: Double = 2

    /// What the reader gets before choosing anything: the size `.title3` resolves to on iOS, and
    /// the leading `VerseRow` was drawn with before this was configurable.
    static let fallback = ReaderTypography(textSize: 20, lineSpacing: 14)

    init(textSize: Double, lineSpacing: Double) {
        self.textSize = Self.clamp(textSize, to: Self.textSizeRange)
        self.lineSpacing = Self.clamp(lineSpacing, to: Self.lineSpacingRange)
    }

    /// A copy with one value replaced, so a caller changing the size does not have to restate
    /// the spacing it is leaving alone.
    func with(textSize: Double) -> ReaderTypography {
        ReaderTypography(textSize: textSize, lineSpacing: lineSpacing)
    }

    func with(lineSpacing: Double) -> ReaderTypography {
        ReaderTypography(textSize: textSize, lineSpacing: lineSpacing)
    }

    /// Anything non-finite falls to the lower bound rather than propagating. `NaN` is the case
    /// that forces the guard — every comparison against it is false, so `min`/`max` alone would
    /// let it straight through to a `Font` that cannot lay it out — and the infinities go the
    /// same way on purpose: a stored value that is not a number is corruption rather than a
    /// choice, and the safe direction to resolve corruption in is the small one. Text too large
    /// to fit a word on the screen is the failure a reader cannot navigate out of.
    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
