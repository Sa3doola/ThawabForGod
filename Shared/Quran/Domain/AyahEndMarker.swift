//
//  AyahEndMarker.swift
//  ThawabForGod
//

import Foundation

/// The end-of-ayah marker: the verse number in Arabic-Indic digits, which KFGQPC Hafs draws as one
/// ornamented sign. Data, not display — the reader's own digit setting is for the numbers the app
/// writes, and this is a glyph of the Mushaf's. Shared so the app and the widget draw one rule.
nonisolated enum AyahEndMarker {
    static func text(verse: Int) -> String {
        // Only ASCII digits map; anything else (a sign on a bad value) is dropped, never subtracted from.
        String(String(verse).unicodeScalars.compactMap { scalar in
            guard (0x30...0x39).contains(scalar.value) else { return nil }
            return Unicode.Scalar(scalar.value - 0x30 + 0x0660).map(Character.init)
        })
    }
}
