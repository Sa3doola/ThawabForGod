//
//  QuranAyahText.swift
//  ThawabForGod
//

import SwiftUI

/// The one place that decides how an ayah's words are drawn.
///
/// **The stored text is never changed, only its drawing.** Copy, share, search and accessibility
/// use the string `attributed` was given, never its result. The result starts as exactly one
/// `AttributedString(text)` and only has a font set on sub-ranges, so its characters cannot differ
/// from the input.
nonisolated enum QuranAyahText {
    /// The face that draws what KFGQPC Hafs cannot.
    static let fallbackFace: ReaderFont = .amiriQuran

    /// `text`, character for character, with a font named only on the stretches `face` cannot
    /// draw. `scaledSize` is already scaled for Dynamic Type, and the font is fixed-size, so it is
    /// not scaled a second time.
    ///
    /// Nothing is named unless the reader's face is KFGQPC Hafs, it registered, and the text holds
    /// the mark: the full build and the Amiri face cost no more than the scan.
    static func attributed(
        _ text: String,
        face: ReaderFont,
        scaledSize: Double,
        hafsIsRegistered: Bool = true
    ) -> AttributedString {
        var result = AttributedString(text)
        guard face == .kfgqpcHafs, hafsIsRegistered, QuranTextFallback.isNeeded(in: text) else {
            return result
        }
        let font = fallbackFace.font(size: scaledSize)
        for range in QuranTextFallback.ranges(in: text) {
            if let attributedRange = Range<AttributedString.Index>(range, in: result) {
                result[attributedRange].font = font
            }
        }
        return result
    }
}
