//
//  HadithContinueRow.swift
//  ThawabForGod
//

import SwiftUI

/// The kitab the reader was last in, offered as one row.
///
/// Names the *division* rather than a narration, which is what `HadithReadingPosition` stores and
/// for the reason it gives: a kitab is read a narration at a time and put down between them, so
/// being returned to the exact paragraph would more often be wrong than right.
struct HadithContinueRow: View {
    let book: BookReference
    /// The division's Arabic title, when the divisions of that collection happen to be loaded.
    let title: String?
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.turn.down.right")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32)
                    .background(theme.accent.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.string(.hadithContinueReading))
                        .appFont(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    label
                }

                Spacer(minLength: 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The division's title where it is known, and its number where it is not.
    ///
    /// A number is a poor label and a good fallback: `كتاب 76` still tells the reader which of
    /// the ninety-seven they are going back to, where a placeholder would tell them nothing.
    @ViewBuilder
    private var label: some View {
        if let title {
            Text(title)
                .appFont(.headline)
                .foregroundStyle(theme.textPrimary)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLanguage.arabic.locale)
        } else {
            HStack(spacing: 4) {
                Text(l10n.string(.hadithBookLabel))
                Text(l10n.string(book.number, grouped: false))
            }
            .appFont(.headline)
            .foregroundStyle(theme.textPrimary)
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 12) {
        HadithContinueRow(
            book: BookReference(collection: "bukhari", number: 1),
            title: "كتاب بدء الوحى",
            action: {}
        )

        HadithContinueRow(
            book: BookReference(collection: "bukhari", number: 76),
            title: nil,
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
