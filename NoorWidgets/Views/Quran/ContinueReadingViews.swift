//
//  ContinueReadingViews.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

// MARK: - Shared by both Quran widgets

extension WidgetLocalization {

    /// A catalogue string with `%1$@`-style values substituted, in the entry's language.
    ///
    /// `WidgetLocalization.string(_:)` takes no arguments, and the two Quran widgets are the first
    /// to need a sentence with holes in it.
    func string(_ key: L10nKey, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    /// `2:255`, in the reader's digits and isolated so the colon cannot reorder in an RTL line.
    func reference(surah: Int, verse: Int, lastVerse: Int? = nil) -> String {
        var numeric = "\(number(surah)):\(number(verse))"
        if let lastVerse, lastVerse != verse { numeric += "\u{2013}\(number(lastVerse))" }
        return "\u{2068}\(numeric)\u{2069}"
    }
}

extension NextPrayerSnapshot.Style {
    /// The surah's name in the entry's language.
    func surahName(arabic: String, english: String) -> String {
        language == .arabic ? arabic : english
    }
}

/// The treatment every Quran widget shares: the theme, the locale carrying the digits, the layout
/// direction, the tap target and the background. The same treatment, in the same order, as
/// `HijriDateWidgetView`.
private struct QuranWidgetChrome: ViewModifier {
    let style: NextPrayerSnapshot.Style
    let link: DeepLink

    private var theme: Theme { Theme(accent: style.accent) }

    func body(content: Content) -> some View {
        content
            .environment(\.theme, theme)
            .environment(\.locale, WidgetLocalization(style).locale)
            .environment(\.layoutDirection, style.language.isRightToLeft ? .rightToLeft : .leftToRight)
            .widgetURL(link.url)
            .containerBackground(for: .widget) { theme.background }
    }
}

extension View {
    func quranWidgetChrome(style: NextPrayerSnapshot.Style, link: DeepLink) -> some View {
        modifier(QuranWidgetChrome(style: style, link: link))
    }
}

/// The sentence shown before the app has published anything.
struct QuranWidgetEmptyView: View {
    let key: L10nKey
    let style: NextPrayerSnapshot.Style

    @Environment(\.widgetFamily) private var family
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

// MARK: - Continue reading

/// Picks the layout for the family.
struct ContinueReadingWidgetView: View {

    let entry: QuranWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var reading: QuranWidgetSnapshot.ContinueReading? { entry.snapshot?.continueReading }

    /// A page when there is one; the verse otherwise. Nothing at all falls back to the Quran tab.
    private var link: DeepLink {
        guard let reading else { return .quran }
        return reading.page.map(DeepLink.quranPage) ?? .quranVerse(reading.ayah)
    }

    var body: some View {
        content
            .quranWidgetChrome(style: entry.style, link: link)
    }

    @ViewBuilder
    private var content: some View {
        if let reading {
            switch family {
            #if os(iOS)
            case .accessoryRectangular:
                ContinueReadingAccessoryView(reading: reading, style: entry.style)
            #endif
            case .systemMedium:
                ContinueReadingMediumView(reading: reading, style: entry.style)
            default:
                ContinueReadingSmallView(reading: reading, style: entry.style)
            }
        } else {
            QuranWidgetEmptyView(key: .quranWidgetContinueEmpty, style: entry.style)
        }
    }
}

/// Header, surah, verse and page: the whole of the small family and the left half of the medium.
private struct ContinueReadingText: View {
    let reading: QuranWidgetSnapshot.ContinueReading
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
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
}

struct ContinueReadingSmallView: View {
    let reading: QuranWidgetSnapshot.ContinueReading
    let style: NextPrayerSnapshot.Style

    var body: some View {
        ContinueReadingText(reading: reading, style: style)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ContinueReadingMediumView: View {
    let reading: QuranWidgetSnapshot.ContinueReading
    let style: NextPrayerSnapshot.Style

    @Environment(\.theme) private var theme

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ContinueReadingText(reading: reading, style: style)

                Spacer(minLength: 0)

                if let footer {
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
    private var footer: String? {
        guard let page = reading.page, let juz = reading.juz else { return nil }
        return l10n.string(.quranPageFooter, l10n.number(juz), l10n.number(page))
    }
}

#if os(iOS)
/// The Lock Screen rectangle: text only. It is tinted by the system, so it reads no theme.
struct ContinueReadingAccessoryView: View {
    let reading: QuranWidgetSnapshot.ContinueReading
    let style: NextPrayerSnapshot.Style

    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(style.surahName(arabic: reading.surahNameArabic, english: reading.surahNameEnglish))
                .appFont(.headline)

            Text(verbatim: detail)
                .appFont(.caption)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let verse = "\(l10n.string(.quranVerseLabel)) \(l10n.number(reading.ayah.verse))"
        guard let page = reading.page else { return verse }
        return "\(verse) · \(l10n.string(.quranPageNumber, l10n.number(page)))"
    }
}
#endif
