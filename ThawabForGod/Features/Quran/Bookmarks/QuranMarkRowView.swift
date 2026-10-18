//
//  QuranMarkRowView.swift
//  ThawabForGod
//

import SwiftUI

/// One mark in the list: the reference, the date (when ordered by date), a highlight's swatch, then
/// an excerpt of the ayah and a note's text.
///
/// Everything corpus-dependent is optional: with no corpus the row is the numeric `s:a` reference
/// alone. The excerpt is drawing only, through `QuranAyahText`; nothing is stored or copied.
struct QuranMarkRowView: View {
    let row: QuranMarkRow
    let reference: String
    /// The ayah's words, or `nil` when the corpus has not loaded or does not hold the ayah.
    let ayahText: String?
    /// Shown only when the list is ordered by date.
    let dateText: String?
    let palette: ReadingPalette

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.quranFaces) private var faces
    @ScaledMetric(relativeTo: .body) private var excerptSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var swatchSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            header
            if let ayahText { excerpt(ayahText) }
            if let note = row.note {
                Text(verbatim: note)
                    .appFont(.body)
                    .foregroundStyle(palette.text)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quran.bookmarks.row")
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            if let color = row.color {
                Circle()
                    .fill(palette.highlight(color))
                    .overlay(Circle().stroke(palette.ornament, lineWidth: 1))
                    .frame(width: swatchSize, height: swatchSize)
                    .accessibilityLabel(Text(l10n.string(color.titleKey)))
            }
            Text(verbatim: reference)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(palette.text)
            Spacer(minLength: AppSpacing.sm)
            if let dateText {
                Text(verbatim: dateText)
                    .appFont(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func excerpt(_ text: String) -> some View {
        Text(QuranAyahText.attributed(
            text, face: .kfgqpcHafs, scaledSize: Double(excerptSize), hafsIsRegistered: faces.contains(.ayahText)
        ))
        .font(faces.font(.ayahText, size: excerptSize))
        .foregroundStyle(palette.secondaryText)
        .lineLimit(row.note == nil ? 2 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
