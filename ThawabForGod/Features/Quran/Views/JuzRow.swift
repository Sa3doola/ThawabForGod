//
//  JuzRow.swift
//  ThawabForGod
//

import SwiftUI

/// One of the thirty parts, with the span it covers.
///
/// The span is shown as two verse references rather than as chapter names: a part that runs from
/// 2:142 to 2:252 is inside one chapter, and naming it twice would say less than the numbers do.
struct JuzRow: View {
    let juz: Juz
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                number

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(l10n.string(.quranJuzLabel))
                        Text(l10n.string(juz.number, grouped: false))
                    }
                    .appFont(.headline)
                    .foregroundStyle(theme.textPrimary)

                    span
                }

                Spacer(minLength: 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var number: some View {
        Text(l10n.string(juz.number, grouped: false))
            .appFont(.footnote, weight: .semibold)
            .foregroundStyle(theme.accent)
            .frame(width: 34, height: 34)
            .background(theme.accent.opacity(0.12), in: .circle)
    }

    /// `2:142 → 2:252`, with the digits in the reader's number system.
    ///
    /// Pinned left-to-right. A verse reference reads chapter-then-verse in both languages, and
    /// under an Arabic layout the bidi algorithm would otherwise reorder the pair around the
    /// arrow — the same reason countdowns are wrapped in directional isolates.
    private var span: some View {
        HStack(spacing: 6) {
            reference(juz.start)
            Image(systemName: "arrow.right")
                .appFont(.caption)
            reference(juz.end)
        }
        .appFont(.caption)
        .foregroundStyle(theme.textSecondary)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func reference(_ verse: VerseReference) -> some View {
        HStack(spacing: 1) {
            Text(l10n.string(verse.surah, grouped: false))
            Text(verbatim: ":")
            Text(l10n.string(verse.verse, grouped: false))
        }
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    JuzRow(
        juz: Juz(
            id: 2,
            start: VerseReference(surah: 2, verse: 142),
            end: VerseReference(surah: 2, verse: 252)
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
