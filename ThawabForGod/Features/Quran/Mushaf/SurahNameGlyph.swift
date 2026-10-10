//
//  SurahNameGlyph.swift
//  ThawabForGod
//

import SwiftUI

/// A surah's calligraphic name ("سورة …") from QUL's surah-name-v2 face, drawn by its ligature
/// string ("surah002", `Surah.nameGlyph`).
///
/// Ported from Mushaf, and the replacement for Noor's own `SurahNameGlyph`, whose face had no
/// redistribution terms (D4). For lists, titles and separated mode; a Mushaf page uses
/// `SurahHeaderGlyph`. Without the face — a public clone — it draws the name in the app's face,
/// never the ligature string, which would print as Latin letters.
struct SurahNameGlyph: View {
    let surah: Surah
    /// The surah's name in the interface language: the accessibility label and the fallback.
    let name: String
    let size: CGFloat
    /// Scales with Dynamic Type like this style (lists, titles); `nil` keeps `size` fixed.
    var relativeTo: Font.TextStyle? = .title

    @Environment(\.quranFaces) private var faces

    var body: some View {
        Group {
            if faces.contains(.surahName), let glyph = surah.nameGlyph {
                Text(verbatim: glyph)
                    .font(relativeTo.map { faces.font(.surahName, size: size, relativeTo: $0) } ?? faces.font(.surahName, size: size))
            } else {
                Text(verbatim: name)
                    .font(relativeTo.map { faces.font(.surahName, size: size, relativeTo: $0) }
                        ?? QuranFaces.chromeFont(size: size * 0.45, weight: .semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
    }
}
