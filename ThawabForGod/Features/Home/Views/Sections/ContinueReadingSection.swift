//
//  ContinueReadingSection.swift
//  ThawabForGod
//

import SwiftUI

/// The way back into the Quran, from the other side of the app.
///
/// It reuses the Quran tab's own `ContinueReadingCard` rather than drawing a second one. The two
/// answer the same question and would drift the first time either changed — and the card already
/// knows how to name a place in the text, which is the only hard part of it.
///
/// What this adds is the heading, because on Home the card is one section among several and needs
/// to say which. On the Quran tab it is the only thing above the lists and says so by position.
struct ContinueReadingSection: View {
    let reading: HomeViewModel.ContinueReading
    let open: (AppRoute) -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(l10n.string(.quranTitle))
                .appFont(.headline, weight: .semibold)
                .foregroundStyle(theme.textPrimary)

            ContinueReadingCard(position: reading.position, surah: reading.surah) {
                open(.quranVerse(reading.position.reference))
            }
        }
    }
}
