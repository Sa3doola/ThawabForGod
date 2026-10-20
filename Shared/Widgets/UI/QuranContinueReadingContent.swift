//
//  QuranContinueReadingContent.swift
//  ThawabForGod
//

import SwiftUI

/// Continue Reading, drawn for one family. Content only: the tap target and the container
/// background belong to the widget extension.
struct QuranContinueReadingContent: View {

    let entry: QuranWidgetEntry
    let family: QuranWidgetFamily

    @Environment(\.theme) private var theme

    private var style: NextPrayerSnapshot.Style { entry.style }
    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        if let reading = entry.snapshot?.continueReading {
            switch family {
            case .rectangular:
                accessory(reading)
            case .medium, .large:
                medium(reading)
            case .small:
                text(reading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            QuranWidgetEmptyView(key: .quranWidgetContinueEmpty, style: style)
        }
    }

    // MARK: - Small and medium

    /// Header, surah, verse and page: the whole of the small family and the left half of the medium.
    private func text(_ reading: QuranWidgetSnapshot.ContinueReading) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(l10n.string(.quranContinueReading))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.accent)
                .lineLimit(1)

            Text(style.surahName(arabic: reading.surahNameArabic, english: reading.surahNameEnglish))
                .appFont(.title3, weight: .semibold)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(verbatim: "\(l10n.string(.quranVerseLabel)) \(l10n.number(reading.ayah.verse))")
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            if let page = reading.page {
                Text(l10n.string(.quranPageNumber, l10n.number(page)))
                    .appFont(.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func medium(_ reading: QuranWidgetSnapshot.ContinueReading) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                text(reading)

                Spacer(minLength: 0)

                if let footer = footer(reading) {
                    Text(footer)
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: AppSpacing.xs)

            Image(systemName: "book.fill")
                .font(.title)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// `Juz 3 · Page 50` where both are known, since the printed page is what names the juz.
    private func footer(_ reading: QuranWidgetSnapshot.ContinueReading) -> String? {
        guard let page = reading.page, let juz = reading.juz else { return nil }
        return l10n.string(.quranPageFooter, l10n.number(juz), l10n.number(page))
    }

    // MARK: - Lock Screen

    /// The rectangle: text only. It is tinted by the system, so it reads no theme.
    private func accessory(_ reading: QuranWidgetSnapshot.ContinueReading) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(style.surahName(arabic: reading.surahNameArabic, english: reading.surahNameEnglish))
                .appFont(.headline)

            Text(verbatim: accessoryDetail(reading))
                .appFont(.caption)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func accessoryDetail(_ reading: QuranWidgetSnapshot.ContinueReading) -> String {
        let verse = "\(l10n.string(.quranVerseLabel)) \(l10n.number(reading.ayah.verse))"
        guard let page = reading.page else { return verse }
        return "\(verse) · \(l10n.string(.quranPageNumber, l10n.number(page)))"
    }
}

/// The sentence shown before the app has published anything.
struct QuranWidgetEmptyView: View {
    let key: L10nKey
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    var body: some View {
        Text(WidgetLocalization(style).string(key))
            .appFont(.footnote)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
