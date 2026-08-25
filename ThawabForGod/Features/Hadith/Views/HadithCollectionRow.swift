//
//  HadithCollectionRow.swift
//  ThawabForGod
//

import SwiftUI

/// One collection, with its compiler and how much of it there is.
///
/// The Arabic title leads and the English follows, in both interface languages — the title of
/// these books *is* Arabic, and `Sahih al-Bukhari` is a transliteration of it rather than a
/// translation. The same reasoning `SurahRow` uses for chapter names.
struct HadithCollectionRow: View {
    let collection: HadithCollection
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(collection.arabicName)
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, AppLanguage.arabic.locale)

                Text(collection.englishName)
                    .appFont(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                counts
            }
            .padding(AppSpacing.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
                .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// `Books: 97 · Hadith: 7,580`, with the digits in the reader's number system.
    ///
    /// Labels with colons rather than "97 books", which Arabic cannot say with one noun form
    /// across every count — the same shape `quranVersesLabel` takes, and for the same reason.
    private var counts: some View {
        HStack(spacing: 10) {
            labelled(.hadithBooksLabel, collection.bookCount)

            Text(verbatim: "·")

            labelled(.hadithNarrationsLabel, collection.hadithCount)
        }
        .appFont(.caption)
        .foregroundStyle(theme.textSecondary)
    }

    private func labelled(_ key: L10nKey, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Text(l10n.string(key))
            Text(l10n.string(value))
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    HadithCollectionRow(
        collection: HadithCollection(
            id: "bukhari",
            arabicName: "صحيح البخاري",
            englishName: "Sahih al-Bukhari",
            arabicAuthor: "الإمام محمد بن إسماعيل البخاري",
            englishAuthor: "Imam Muhammad ibn Isma'il al-Bukhari",
            bookCount: 97,
            hadithCount: 7580
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
