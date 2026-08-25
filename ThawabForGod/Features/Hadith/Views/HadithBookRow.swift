//
//  HadithBookRow.swift
//  ThawabForGod
//

import SwiftUI

/// One kitab, with its number and how many narrations are in it.
///
/// The number is shown because it is part of how these divisions are referred to, and because
/// `كتاب الإيمان` is the title of a kitab in *both* collections — the number is what tells the
/// reader which one they are looking at.
struct HadithBookRow: View {
    let book: HadithBook
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                number

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.arabicTitle)
                        .appFont(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .environment(\.layoutDirection, .rightToLeft)
                        .environment(\.locale, AppLanguage.arabic.locale)

                    Text(book.englishTitle)
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer(minLength: 8)

                count
            }
            .padding(AppSpacing.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
                .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var number: some View {
        Text(l10n.string(book.number, grouped: false))
            .appFont(.footnote, weight: .semibold)
            .foregroundStyle(theme.accent)
            .frame(width: 34, height: 34)
            .background(theme.accent.opacity(0.12), in: .circle)
    }

    private var count: some View {
        Text(l10n.string(book.hadithCount))
            .appFont(.caption)
            .foregroundStyle(theme.textSecondary)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    HadithBookRow(
        book: HadithBook(
            collectionID: "bukhari",
            number: 1,
            arabicTitle: "كتاب بدء الوحى",
            englishTitle: "Revelation",
            hadithCount: 7
        ),
        action: {}
    )
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
