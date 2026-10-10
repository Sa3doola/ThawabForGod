//
//  SurahHeaderGlyph.swift
//  ThawabForGod
//

import SwiftUI

/// A surah header line on a Mushaf page, and the banner over a surah in separated mode.
///
/// Ported from Mushaf. **Paper** draws one `QCF_SurahHeader_COLOR` glyph: the frame and the name in
/// the print's own colours (a COLR font, so no foreground style applies). **Sepia and Dark** draw
/// QUL quran-common's empty frame tinted in the page's ornament colour, with the surah-name-v2 name
/// centred on it in the text colour, in the same box — the print's red and gold fight a tinted or
/// dark ground. Without the QUL faces (a public clone) it draws the plain name in the app's face.
struct SurahHeaderGlyph: View {
    let surah: Surah
    /// The surah's name in the interface language: the accessibility label and the fallback text.
    let name: String
    /// From `MushafPageMetrics.headerFontSize`: the glyph fills the slot's width or height.
    let fontSize: CGFloat

    @Environment(\.quranFaces) private var faces
    @Environment(\.readingPalette) private var palette
    @Environment(\.surahHeaderFrame) private var frameGlyph

    /// quran-common's frame glyph is 8.05 em wide (its box 1.0 em tall); drawn as wide as the print
    /// header (`MushafPageMetrics.headerAdvanceEm` of `fontSize`).
    static let frameAdvanceEm: CGFloat = 8.05
    /// surah-name-v2's size relative to the frame's: the name fills the middle cartouche (the
    /// widest, Al-Mutaffifin at 2.49 em, still fits).
    static let nameScale: CGFloat = 0.75

    var body: some View {
        Group {
            if palette.usesPrintHeader, faces.contains(.surahHeader), let glyph = surah.headerGlyph {
                Text(verbatim: glyph)
                    .font(faces.font(.surahHeader, size: fontSize))
            } else if !palette.usesPrintHeader, faces.contains(.quranCommon), faces.contains(.surahName),
                      let frameGlyph, let nameGlyph = surah.nameGlyph {
                // Both glyphs centre their ink on their own text box, so centring the boxes centres
                // the name in the frame.
                let frameSize = fontSize * MushafPageMetrics.headerAdvanceEm / Self.frameAdvanceEm
                ZStack {
                    Text(verbatim: frameGlyph)
                        .font(faces.font(.quranCommon, size: frameSize))
                        .foregroundStyle(palette.ornament)
                    Text(verbatim: nameGlyph)
                        .font(faces.font(.surahName, size: frameSize * Self.nameScale))
                        .foregroundStyle(palette.text)
                }
            } else {
                Text(verbatim: name)
                    .font(QuranFaces.chromeFont(size: fontSize * MushafPageMetrics.headerHeightEm * 0.5, weight: .semibold))
                    .foregroundStyle(palette.text)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
    }
}

extension EnvironmentValues {
    /// The quran-common glyph for an empty surah-header frame (`QuranCorpus.surahHeaderFrame`).
    @Entry var surahHeaderFrame: String? = nil
}
