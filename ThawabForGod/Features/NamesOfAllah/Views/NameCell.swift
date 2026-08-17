//
//  NameCell.swift
//  ThawabForGod
//

import SwiftUI

/// One tile in the names grid: the number, the name, and how to say it.
///
/// Values in, closure out — no view model, so it can be previewed in either language and reused
/// by a search result list unchanged.
struct NameCell: View {
    let name: DivineName
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                number
                arabic

                if let transliteration = name.transliteration {
                    Text(transliteration)
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(theme.surface, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    /// The canonical position, through `LocalizationManager` so it is ٣ rather than 3 on an
    /// Arabic screen. Ungrouped — it names a position rather than counting anything.
    private var number: some View {
        Text(l10n.string(name.order, grouped: false))
            .appFont(.caption, weight: .semibold)
            .monospacedDigit()
            .foregroundStyle(theme.accent)
    }

    /// Forced right-to-left, for the same reason `DhikrCard` does it: the name is Arabic whatever
    /// language the interface is in, and the tile should not hang it from the wrong edge.
    private var arabic: some View {
        Text(name.arabic)
            .appFont(.title2)
            .foregroundStyle(theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    /// Read as one phrase — "Name 3, الملك, The King" — rather than three unrelated fragments.
    private var accessibilityLabel: String {
        [
            l10n.string(.namesNumberLabel),
            l10n.string(name.order, grouped: false),
            name.arabic,
            name.meaning
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
        NameCell(
            name: DivineName(
                id: 1,
                arabic: "الرَّحْمَنُ",
                transliteration: "Ar Rahmaan",
                meaning: "The Beneficent",
                explanation: nil,
                reference: "(1:3) (17:110)"
            ),
            action: {}
        )
        NameCell(
            name: DivineName(
                id: 84,
                arabic: "مَالِكُ الْمُلْكِ",
                transliteration: "Maalik Ul Mulk",
                meaning: "The Owner of All Sovereignty",
                explanation: nil,
                reference: "(3:26)"
            ),
            action: {}
        )
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
