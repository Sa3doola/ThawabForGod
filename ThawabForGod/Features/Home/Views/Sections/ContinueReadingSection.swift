//
//  ContinueReadingSection.swift
//  ThawabForGod
//

import SwiftUI

/// Where the reader stopped in the Quran, as one tappable card.
///
/// Drawn only when there is a position; the caller decides that, since a card saying "continue"
/// over nothing is worse than no card.
struct ContinueReadingSection: View {
    let reading: HomeViewModel.ContinueReading
    let open: (AppRoute) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            open(.quranContinue)
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "book")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32)
                    .background(theme.accent.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.string(.quranContinueReading))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    Text(place)
                        .appFont(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.continueReading")
    }

    /// `Al-Kahf — Verse 40`, or the verse alone where the chapter's name is not known.
    private var place: String {
        let verse = "\(l10n.string(.quranVerseLabel)) \(l10n.string(reading.reference.verse, grouped: false))"
        guard let name = reading.surahName else { return verse }
        return "\(name) — \(verse)"
    }
}
