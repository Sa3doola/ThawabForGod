//
//  QuranTypography.swift
//  ThawabForGod
//

import SwiftUI

/// How each Quranic face is set: the `Font`, and the leading its marks need.
///
/// Every size here is **fixed** — `Font.custom(_:fixedSize:)` — because the caller has already
/// scaled it for Dynamic Type (see `ReadingFontModifier`). `Font.custom(_:size:)` would scale it a
/// second time, relative to `.body`, and a reader at an accessibility size would get the square of
/// the enlargement they asked for.
nonisolated extension ReaderFont {
    func font(size: Double) -> Font {
        .custom(postScriptName, fixedSize: size)
    }

    /// The gap the face needs between two wrapped lines so the marks of one clear the next.
    ///
    /// Per face rather than one number, because the two faces disagree by nearly a factor of two.
    /// KFGQPC's marks sit close to the letters; Amiri stacks its vowels high and deep, and at the
    /// leading that suits KFGQPC a kasra on one line lands in the shadda of the line below. These
    /// are the floor — the reader's own line-spacing control adds to them, never subtracts.
    func lineSpacing(for size: Double) -> Double {
        switch self {
        case .kfgqpcHafs: size * 0.45
        case .amiriQuran: size * 0.75
        }
    }
}

nonisolated extension AyahMarkerStyle {
    /// The marker's size as a share of the verse's. Small enough that the medallion sits inside
    /// the line rather than pushing it apart; large enough that a three-digit number stays legible
    /// inside the ring.
    static let scale: Double = 1.5

    /// The face at a size that is already final, for the reason the note on `ReaderFont` gives.
    func font(size: Double) -> Font {
        .custom(postScriptName, fixedSize: size)
    }
}
