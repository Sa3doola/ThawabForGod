//
//  CategoryRow.swift
//  ThawabForGod
//

import SwiftUI

/// One chapter of Hisn al-Muslim in the browse list.
///
/// **Both titles, always, and the Arabic is never the small one.** In an English interface the
/// English title leads because that is what the reader scans by, and the Arabic sits under it —
/// but the reverse is not symmetric: for an Arabic reader the Arabic title *is* the chapter, and
/// the English rendering is this project's guess at it, unverified (see
/// `Resources/Corpus/README.md`), so it is not shown at all. An unverified translation printed
/// under the real title would read as an equal claim.
///
/// A `Button` rather than a tappable `HStack`: it is what gives the row a hit region, a pressed
/// state and a VoiceOver trait that says "button" without any of it being described by hand.
struct CategoryRow: View {
    let category: AdhkarCategory
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var isArabic: Bool { l10n.language == .arabic }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title(in: l10n.language))
                        .appFont(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !isArabic {
                        Text(category.titleArabic)
                            .appFont(.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            // The title is Arabic whatever the interface is, so it hangs from the
                            // right edge and is read in an Arabic voice. Set on the leaf, which is
                            // safe: the view is *created* with this direction rather than having
                            // it changed underneath a UIKit-backed container. See the note in
                            // CLAUDE.md on why `.localized(_:)` no longer does this globally.
                            .environment(\.layoutDirection, .rightToLeft)
                            .environment(\.locale, AppLanguage.arabic.locale)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                count

                // Mirrors for Arabic on its own — a chevron that kept pointing right on an RTL
                // screen would point back the way the reader came.
                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(AppSpacing.row)
            .appCard()
            .appHover()
            .contentShape(.rect(cornerRadius: AppRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.title(in: l10n.language))
        .accessibilityValue(l10n.string(.adhkarCategoryCount, l10n.string(category.dhikrCount, grouped: false)))
    }

    /// How many adhkar are in the chapter.
    ///
    /// Drawn only where it tells the reader something. 79 of the 132 chapters hold exactly one
    /// dhikr, and a badge saying "1" on more than half the rows is a column of noise that makes
    /// the badges that matter — the chapter of 24, the chapter of 12 — harder to pick out rather
    /// than easier.
    @ViewBuilder
    private var count: some View {
        if category.dhikrCount > 1 {
            Text(l10n.string(category.dhikrCount, grouped: false))
                .appFont(.caption, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 3)
                .background(theme.separator.opacity(0.5), in: .rect(cornerRadius: AppRadius.sm))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    let sample = [
        AdhkarCategory(
            id: "morning-evening",
            titleArabic: "أذكار الصباح والمساء",
            titleEnglish: "Morning & evening",
            group: .daily,
            sortOrder: 1,
            dhikrCount: 24
        ),
        AdhkarCategory(
            id: "entering-the-market",
            titleArabic: "دعاء دخول السوق",
            titleEnglish: "Entering the market",
            group: .travel,
            sortOrder: 98,
            dhikrCount: 1
        ),
    ]

    return VStack(spacing: 12) {
        ForEach(sample) { category in
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
