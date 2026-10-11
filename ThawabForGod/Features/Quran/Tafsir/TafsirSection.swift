//
//  TafsirSection.swift
//  ThawabForGod
//

import SwiftUI

/// The ayah panel's Tafsir section: "Tafsir of ayahs 2:3–4" for a group, the text collapsed to about
/// eight lines with "Read more" (the full tafsir reader), and the attribution.
///
/// Ported from Mushaf. It draws a phase and loads nothing: `AyahPanelViewModel` owns the load, the
/// "same pack, ayah already in range" short-cut and the stale-result guard (T16). Silence and
/// failure are different words on screen: a commentary that passes over a verse has no note *there*;
/// a pack that could not be read is a fault.
struct TafsirSection: View {
    let phase: AyahPanelTafsirPhase
    /// "Al-Baqarah 2:255", for the reader's heading.
    let reference: String
    @Binding var showsReader: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.readingPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var latinSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var arabicSize: CGFloat = 18

    /// Height of the whole text, to know whether the collapsed frame hides some of it.
    @State private var fullHeight: CGFloat = 0

    /// Lines shown before "Read more".
    private static let collapsedLines: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch phase {
            case .idle:
                EmptyView()
            case .loaded(let loaded):
                if loaded.entry.isGroup { groupLabel(loaded.entry) }
                collapsedText(loaded)
                Self.attribution(loaded.pack, l10n: l10n, palette: palette)
            case .silent:
                note(l10n.string(.tafsirSilent))
            case .unavailable:
                note(l10n.string(.tafsirUnavailable))
            }
        }
        .sheet(isPresented: $showsReader) {
            if case .loaded(let loaded) = phase {
                TafsirReaderView(loaded: loaded, reference: reference)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(verbatim: text)
            .appFont(.subheadline)
            .foregroundStyle(palette.secondaryText)
            .accessibilityIdentifier("quran.panel.tafsirNote")
    }

    private func groupLabel(_ entry: TafsirEntry) -> some View {
        Text(verbatim: Self.groupText(entry, l10n: l10n, isRightToLeft: layoutDirection == .rightToLeft))
            .appFont(.subheadline, weight: .medium)
            .foregroundStyle(palette.secondaryText)
    }

    private func collapsedText(_ loaded: AyahPanelTafsir) -> some View {
        let isArabic = loaded.pack.direction.isRightToLeft
        let fontSize = isArabic ? arabicSize : latinSize
        let cap = Self.collapsedLines * fontSize * (isArabic ? 1.9 : 1.42)
        let isClipped = fullHeight > cap + 1
        return VStack(alignment: .leading, spacing: 6) {
            TafsirTextView(
                document: loaded.document, direction: loaded.pack.direction, fontSize: fontSize,
                textColor: palette.text, headingColor: palette.ornament
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
            .frame(maxHeight: cap, alignment: .top)
            .clipped()
            .mask {
                if isClipped {
                    FadeMask(edge: .bottom, fadeFraction: min(1, fontSize * 2 / cap))
                } else {
                    Rectangle()
                }
            }
            if isClipped {
                Button { showsReader = true } label: {
                    Label {
                        Text(l10n.string(.quranTafsirReadMore))
                    } icon: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                }
                .buttonStyle(.panelPlain)
                .accessibilityIdentifier("quran.panel.readMore")
            }
        }
    }

    // MARK: Shared with the reader

    /// "Tafsir of ayahs 2:3–5", digits in the reader's choice.
    static func groupText(_ entry: TafsirEntry, l10n: LocalizationManager, isRightToLeft: Bool) -> String {
        let range = entry.rangeText(format: { l10n.string($0, grouped: false) }, isRightToLeft: isRightToLeft)
        return l10n.string(.quranTafsirOfAyahs, range)
    }

    /// "Tafsir al-Jalalayn · Jalal al-Din al-Mahalli and al-Suyuti": attribution under every tafsir.
    static func attribution(_ pack: ContentPack, l10n: LocalizationManager, palette: ReadingPalette) -> some View {
        Text(verbatim: "\(pack.name(in: l10n.language)) · \(pack.author(in: l10n.language))")
            .appFont(.caption)
            .foregroundStyle(palette.secondaryText)
    }
}
