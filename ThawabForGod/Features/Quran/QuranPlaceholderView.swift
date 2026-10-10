//
//  QuranPlaceholderView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran tab while its reader is rebuilt on the engine ported from Mushaf (M3–M5).
///
/// A screen that says so rather than an empty one: the tab stays where it is — removing it would
/// renumber ⌘1…⌘4 and the tab bar for a few weeks of a branch — and a reader who opens it learns
/// why there is nothing to read yet. `QuranCoordinator` keeps any verse a route asked for.
struct QuranPlaceholderView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(l10n.string(.quranComingSoon))
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
            } icon: {
                Image(systemName: "book.closed")
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationTitle(l10n.string(.quranTitle))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        QuranPlaceholderView()
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
