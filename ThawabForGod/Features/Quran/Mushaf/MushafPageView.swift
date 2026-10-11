//
//  MushafPageView.swift
//  ThawabForGod
//

import SwiftUI

/// One Mushaf page with its chrome: header (surah name · juz), the style's line slots, footer
/// (juz · page). Ported from Mushaf; the digits are the app's `NumberSystem`, not a Quran setting.
struct MushafPageView: View {
    let style: MushafStyle
    let page: MushafPage
    let basmala: String
    let surahs: [Surah]
    let services: MushafRenderServices
    let selectedAyah: VerseReference?
    /// The reader's marks on this page's ayahs. When one is bookmarked a small ribbon hangs from
    /// the top outer corner.
    var marks: QuranAyahMarkSnapshot = .empty
    /// Juz, hizb, quarter and sajdah labels for the outer margin (empty when hidden).
    var marginMarkers: [MushafMarginMarker] = []
    /// In a spread, the edge facing the other page; the page hugs it. `nil` centres the page.
    var gutterEdge: HorizontalAlignment?
    let onSelect: (VerseReference) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.readingPalette) private var palette

    /// Side margin of the page; the outer one holds the margin labels.
    static let sideMargin: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                MushafPageContent(
                    style: style,
                    page: page,
                    basmala: basmala,
                    surahs: surahs,
                    services: services,
                    selectedAyah: selectedAyah,
                    marks: marks,
                    marginMarkers: marginMarkers,
                    marginWidth: Self.sideMargin,
                    onSelect: onSelect
                )
                footer
            }
            .padding(.horizontal, Self.sideMargin)
            .overlay(alignment: ribbonAlignment) {
                if marks.hasBookmark { ribbon }
            }
            // The printed page's proportions keep wide screens from stretching lines into huge
            // word gaps.
            .frame(maxWidth: geometry.size.height * style.pageAspectRatio)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: Alignment(horizontal: gutterEdge ?? .center, vertical: .center)
            )
        }
        .background(palette.background)
    }

    /// The page's outer top corner on screen: right for odd pages, left for even ones. Overlay
    /// alignments follow the layout direction, which the pager forces to right-to-left.
    private var ribbonAlignment: Alignment {
        let onRight = page.number % 2 == 1
        return onRight == (layoutDirection == .leftToRight) ? .topTrailing : .topLeading
    }

    /// A bookmark ribbon at the top of the outer margin, over the header line. VoiceOver reads the
    /// bookmark on the ayah itself.
    private var ribbon: some View {
        BookmarkRibbon()
            .fill(palette.ornament)
            .frame(width: 10, height: 22)
            .padding(.horizontal, 2)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var surahName: String {
        guard let number = page.firstAyah?.surah, surahs.indices.contains(number - 1) else { return "" }
        return surahs[number - 1].name(in: l10n.language)
    }

    private var header: some View {
        HStack {
            Text(verbatim: surahName)
            Spacer()
            Text(l10n.string(.quranJuzNumber, l10n.string(page.juz, grouped: false)))
        }
        .appFont(.footnote)
        .foregroundStyle(palette.secondaryText)
        .padding(.vertical, 6)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var footer: some View {
        Text(l10n.string(
            .quranPageFooter,
            l10n.string(page.juz, grouped: false),
            l10n.string(page.number, grouped: false)
        ))
            .appFont(.caption)
            .foregroundStyle(palette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// A ribbon with a notched end, hanging from the top edge.
nonisolated struct BookmarkRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.45))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
