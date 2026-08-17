//
//  QiblaFormatting.swift
//  ThawabForGod
//

import Foundation

/// The two units this screen prints, resolved through the user's digit choice.
///
/// An extension rather than free functions so every number on the screen still arrives via the
/// same object the rest of the app formats through — no interpolation, no `String(format:)`,
/// and Arabic-Indic digits wherever the user asked for them.
extension LocalizationManager {

    /// A bearing, as `56.6°`.
    ///
    /// Isolated left-to-right for the same reason `countdownString(_:)` is: the degree sign is
    /// a directionally neutral character, so at the end of a number inside an Arabic paragraph
    /// the bidi algorithm hands it the paragraph's direction and renders it on the *left* of
    /// the digits. The isolate pins it where it belongs without touching the digits themselves.
    func degreesString(_ value: Double) -> String {
        "\u{2066}\(string(value, fractionDigits: 1))°\u{2069}" // LRI … POP DIRECTIONAL ISOLATE
    }

    /// A distance in whole kilometres, with the locale's thousands separator.
    ///
    /// Metres would be false precision — the input is a coarse location fix — and the unit is a
    /// real word in both languages, so number-then-unit reads correctly in each without help.
    func kilometresString(_ metres: Double) -> String {
        "\(string(Int((metres / 1000).rounded()))) \(string(.qiblaDistanceUnitKilometres))"
    }
}
