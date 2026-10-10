//
//  MarginMarkerLabel.swift
//  ThawabForGod
//

import SwiftUI

/// A juz, hizb, quarter or sajdah label in a page's outer margin, turned to run along the margin
/// (the margin is narrower than any label). Ported from Mushaf.
struct MarginMarkerLabel: View {
    let kind: MushafMarginMarker.Kind
    /// From the page's slot height: the label is part of the fitted page, not of the chrome.
    let size: CGFloat
    /// The label sits in the right margin (odd pages); it then reads top to bottom.
    let isRightMargin: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.readingPalette) private var palette

    var body: some View {
        HStack(spacing: size * 0.3) {
            if kind == .sajdah {
                Text(verbatim: "۩")
            }
            Text(Self.title(kind, l10n: l10n))
        }
        .font(QuranFaces.chromeFont(size: size, weight: .medium))
        .foregroundStyle(palette.ornament)
        .fixedSize()
        .rotationEffect(.degrees(isRightMargin ? 90 : -90))
    }

    /// The label's words, also read by VoiceOver with the ayah the marker belongs to.
    static func title(_ kind: MushafMarginMarker.Kind, l10n: LocalizationManager) -> String {
        switch kind {
        case .juz(let juz):
            l10n.string(.quranJuzNumber, l10n.string(juz, grouped: false))
        case .hizb(let hizb):
            l10n.string(.quranMarginHizb, l10n.string(hizb, grouped: false))
        case .quarter(1, let hizb):
            l10n.string(.quranMarginQuarterHizb, l10n.string(hizb, grouped: false))
        case .quarter(2, let hizb):
            l10n.string(.quranMarginHalfHizb, l10n.string(hizb, grouped: false))
        case .quarter(_, let hizb):
            l10n.string(.quranMarginThreeQuarterHizb, l10n.string(hizb, grouped: false))
        case .sajdah:
            l10n.string(.quranMarginSajdah)
        }
    }
}
