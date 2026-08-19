//
//  QuranView.swift
//  ThawabForGod
//

import SwiftUI

/// The Quran tab, before there is a Quran to read.
///
/// A placeholder with nothing behind it — no view model, no coordinator, no repository — because
/// there is nothing yet for any of them to hold. Phase 2 fills this folder out through all the
/// layers the other features have; what this file exists for is the tab, which is worth putting
/// in place first so the reading screen is built into a slot that already exists rather than
/// arriving with a navigation change attached.
///
/// It says so on the screen rather than showing an empty page, and it says what the screen will
/// be — a promise the reader can hold the app to.
struct QuranView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: AppTab.quran.symbol)
                    .appFont(.largeTitle)
                    .foregroundStyle(theme.accent)

                Text(l10n.string(.quranComingSoonTitle))
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)

                Text(l10n.string(.quranComingSoonBody))
                    .appFont(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity, alignment: .center)
            // One element rather than three: VoiceOver reads the promise as a sentence, and
            // the symbol is decoration that adds nothing to it.
            .accessibilityElement(children: .combine)
        }
        .background(theme.background)
        .navigationTitle(l10n.string(.quranTitle))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    NavigationStack {
        QuranView()
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
