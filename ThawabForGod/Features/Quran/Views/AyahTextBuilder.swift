//
//  AyahTextBuilder.swift
//  ThawabForGod
//

import SwiftUI

/// One verse as a single paragraph: the words, then the medallion that numbers them.
///
/// An `AttributedString` with a font on the marker run rather than two `Text`s joined with `+`,
/// which the current SDK deprecates, or interpolated into a `LocalizedStringKey`, which would put a
/// `"%@ %@"` key into the String Catalog for a string nobody translates. The words carry no font of
/// their own and so take the reading face from the environment; only the marker names one.
enum AyahTextBuilder {

    /// Between the last word and the medallion. **No-break**, so a line never ends on the words
    /// and starts the next with a lone number — the marker belongs to its verse. Both faces carry
    /// a glyph for it, so it borrows no fallback font and changes no line height.
    static let separator = "\u{00A0}"

    /// - Parameter number: the verse's number, or `nil` to set the words alone — the reader's
    ///   "show verse numbers" switch.
    static func text(_ words: String, number: Int?, markerFont: Font) -> AttributedString {
        var paragraph = AttributedString(words)
        guard let number else { return paragraph }

        // **`String(number)`, not `LocalizationManager`, and this is the one deliberate exception
        // to the project's rule that numbers go through it.** The marker faces draw the medallion
        // by a ligature over the typed digits, and those ligatures were built on ASCII 0–9: route
        // the number through the Arabic-Indic formatter and the font sees digits it has no
        // ligature for and draws them bare. The reader still sees Arabic numerals — the glyph
        // inside every medallion is Arabic-Indic — and VoiceOver reads the label, which does go
        // through the formatter.
        var marker = AttributedString(String(number))
        marker.font = markerFont

        paragraph.append(AttributedString(separator))
        paragraph.append(marker)
        return paragraph
    }
}
