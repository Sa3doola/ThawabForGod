//
//  AyahShareText.swift
//  ThawabForGod
//

import Foundation

/// The one builder of what Copy and Share give. Pure.
///
/// `ayahText` is `Ayah.text` byte-for-byte: never `QuranAyahText` output and never the verse
/// marker, so what is pasted is the corpus's own character sequence.
nonisolated enum AyahShareText {
    /// The Arabic and its reference, then each shown translation as plain text (no footnote
    /// numbers) followed by its pack's name, blocks separated by a blank line.
    static func make(ayahText: String, reference: String, translations: [(text: String, packName: String)]) -> String {
        var parts = ["\(ayahText) [\(reference)]"]
        for item in translations {
            parts.append("\(item.text)\n(\(item.packName))")
        }
        return parts.joined(separator: "\n\n")
    }
}
