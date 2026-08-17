//
//  CategoryRow.swift
//  ThawabForGod
//

import SwiftUI

/// One heading in the adhkar list.
///
/// A `Button` rather than a tappable `HStack`: it is what gives the row a hit region, a pressed
/// state and a VoiceOver trait that says "button" without any of it being described by hand.
struct CategoryRow: View {
    let category: AdhkarCategory
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: category.symbolName)
                    .appFont(.title2)
                    .foregroundStyle(theme.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.string(category.titleKey))
                        .appFont(.headline)
                        .foregroundStyle(theme.textPrimary)

                    Text(l10n.string(category.subtitleKey))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Mirrors for Arabic on its own — a chevron that kept pointing right on an RTL
                // screen would point back the way the reader came.
                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(16)
            .background(theme.surface, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 12) {
        ForEach(AdhkarCategory.allCases) { category in
            CategoryRow(category: category, action: {})
        }
    }
    .padding()
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
