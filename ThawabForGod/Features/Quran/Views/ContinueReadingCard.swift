//
//  ContinueReadingCard.swift
//  ThawabForGod
//

import SwiftUI

/// The way back into the text, above the lists.
///
/// Above the segmented control rather than inside one of its segments, because it is not a way of
/// *choosing* where to start — it is the answer to the question the reader most often opens this
/// tab with, and it belongs before the choice rather than behind it.
///
/// It is absent, not disabled, before anything has been read. A control that says "continue" when
/// there is nothing to continue is worse than no control.
struct ContinueReadingCard: View {
    let position: ReadingPosition
    let surah: Surah?
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "book")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.string(.quranContinueReading))
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(theme.textSecondary)

                    Text(place)
                        .appFont(.body, weight: .medium)
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The chapter's Arabic name and the verse — the one line that says where "continue" goes.
    ///
    /// The name stays Arabic in either interface language, as it does everywhere else a chapter
    /// is named; the number follows the reader's digits.
    private var place: String {
        let name = surah?.arabicName ?? ""
        let verse = l10n.string(position.reference.verse, grouped: false)
        return "\(name) \(l10n.string(.quranVerseLabel)) \(verse)"
    }
}
