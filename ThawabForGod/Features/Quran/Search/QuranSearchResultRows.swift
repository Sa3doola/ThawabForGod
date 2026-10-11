//
//  QuranSearchResultRows.swift
//  ThawabForGod
//

import SwiftUI

/// The words a result matched, drawn as a background behind them. The text is the ayah's own:
/// highlighting only sets attributes on ranges and never changes a character.
enum QuranSearchResultText {
    /// `bold` only for system-font text: the Hafs face has no bold, and asking for one could make
    /// the words fall back to another font.
    static func highlighted(
        _ base: AttributedString, text: String, ranges: [Range<String.Index>], palette: ReadingPalette, bold: Bool = false
    ) -> AttributedString {
        var attributed = base
        for range in ranges {
            guard let target = Range<AttributedString.Index>(range, in: attributed) else { continue }
            attributed[target].backgroundColor = palette.highlight(.yellow)
            if bold { attributed[target].inlinePresentationIntent = .stronglyEmphasized }
        }
        return attributed
    }
}

/// An Arabic result: the reference, then the Hafs words with the matched ones marked.
struct QuranSearchArabicRow: View {
    let reference: String
    let text: String
    let query: QuranSearchQuery
    let palette: ReadingPalette

    @Environment(\.quranFaces) private var faces
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(verbatim: reference)
                .appFont(.caption)
                .foregroundStyle(palette.secondaryText)
            Text(words)
                .font(faces.font(.ayahText, size: size))
                .lineSpacing(6)
                .foregroundStyle(palette.text)
                // A Mac button label is one line unless given a limit; the longest ayahs end in an
                // ellipsis after ten lines.
                .lineLimit(10)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quran.search.result")
    }

    private var words: AttributedString {
        let base = QuranAyahText.attributed(
            text, face: .kfgqpcHafs, scaledSize: Double(size), hafsIsRegistered: faces.contains(.ayahText)
        )
        return QuranSearchResultText.highlighted(
            base, text: text, ranges: QuranSearchHighlight.arabicRanges(in: text, query: query), palette: palette
        )
    }
}

/// A translation result: the reference (and the pack's name when several are installed), then the
/// plain text with the matched words marked and in bold.
struct QuranSearchTranslationRow: View {
    let reference: String
    let item: TranslationText
    let pack: ContentPack?
    let showsPack: Bool
    let query: QuranSearchQuery
    let palette: ReadingPalette

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        let plain = TranslationDocument(item).plainText
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(verbatim: reference)
                if showsPack, let pack { Text(verbatim: "· \(pack.name(in: l10n.language))") }
            }
            .appFont(.caption)
            .foregroundStyle(palette.secondaryText)
            Text(QuranSearchResultText.highlighted(
                AttributedString(plain), text: plain,
                ranges: QuranSearchHighlight.latinRanges(in: plain, query: query), palette: palette, bold: true
            ))
            .appFont(.body)
            .foregroundStyle(palette.text)
            .lineLimit(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.layoutDirection, pack?.direction.isRightToLeft == true ? .rightToLeft : .leftToRight)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quran.search.result")
    }
}
