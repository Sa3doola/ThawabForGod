//
//  AyahOfTheDayViews.swift
//  NoorWidgets
//

import SwiftUI
import WidgetKit

/// Picks the layout for the family.
struct AyahOfTheDayWidgetView: View {

    let entry: QuranWidgetEntry

    @Environment(\.widgetFamily) private var family

    private var day: QuranWidgetSnapshot.DailyAyah? { entry.snapshot?.dailyAyah(for: entry.date) }

    private var link: DeepLink { day.map { .quranVerse($0.first) } ?? .quran }

    var body: some View {
        content
            .quranWidgetChrome(style: entry.style, link: link)
    }

    @ViewBuilder
    private var content: some View {
        if let day {
            switch family {
            #if os(iOS)
            case .accessoryRectangular:
                AyahOfTheDayAccessoryView(day: day, style: entry.style, hasHafs: entry.hasHafs)
            #endif
            case .systemLarge:
                AyahOfTheDayBody(day: day, style: entry.style, hasHafs: entry.hasHafs, isLarge: true)
            default:
                AyahOfTheDayBody(day: day, style: entry.style, hasHafs: entry.hasHafs, isLarge: false)
            }
        } else {
            QuranWidgetEmptyView(key: .quranWidgetAyahEmpty, style: entry.style)
        }
    }
}

/// The reference line and the accessibility label both views share.
private extension QuranWidgetSnapshot.DailyAyah {
    func referenceText(_ style: NextPrayerSnapshot.Style) -> String {
        let l10n = WidgetLocalization(style)
        let name = style.surahName(arabic: surahNameArabic, english: surahNameEnglish)
        return "\(name) \(l10n.reference(surah: first.surah, verse: first.verse, lastVerse: lastVerse))"
    }

    func spokenReference(_ style: NextPrayerSnapshot.Style) -> String {
        let l10n = WidgetLocalization(style)
        let name = style.surahName(arabic: surahNameArabic, english: surahNameEnglish)
        if lastVerse > first.verse {
            return l10n.string(
                .quranWidgetAyahRangeLabel, name, l10n.number(first.verse), l10n.number(lastVerse)
            )
        }
        return l10n.string(.quranWidgetAyahLabel, name, l10n.number(first.verse))
    }
}

/// Medium and large: the Arabic, its translation on the large, and the reference.
struct AyahOfTheDayBody: View {
    let day: QuranWidgetSnapshot.DailyAyah
    let style: NextPrayerSnapshot.Style
    let hasHafs: Bool
    let isLarge: Bool

    @Environment(\.theme) private var theme

    /// Registered in this process, now: a held entry may be rendered where the timeline build never ran.
    private var canDrawArabic: Bool { hasHafs && QuranWidgetFontRegistration.register() }

    var body: some View {
        let showsArabic = canDrawArabic
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if showsArabic {
                QuranWidgetArabicText(
                    texts: day.texts,
                    firstVerse: day.first.verse,
                    size: isLarge ? 24 : 20,
                    lineLimit: isLarge ? 6 : 3
                )
                .foregroundStyle(theme.textPrimary)
            }

            if isLarge, let translation = day.translation, let text = translation.texts.first {
                translationBlock(translation, text: text)
            }

            Spacer(minLength: 0)

            // With no registered face the reference is the whole content, so it takes the weight
            // the Arabic would have had.
            Text(day.referenceText(style))
                .appFont(showsArabic ? .footnote : .title3, weight: showsArabic ? .regular : .semibold)
                .foregroundStyle(showsArabic ? theme.textSecondary : theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(showsArabic: showsArabic))
    }

    @ViewBuilder
    private func translationBlock(_ translation: QuranWidgetSnapshot.Translation, text: String) -> some View {
        let direction: LayoutDirection = translation.isRightToLeft ? .rightToLeft : .leftToRight
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: text)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(5)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Last, so `.leading` follows the translation's own direction, not the UI's.
                .environment(\.layoutDirection, direction)

            Text(style.surahName(arabic: translation.nameArabic, english: translation.nameEnglish))
                .appFont(.caption)
                .foregroundStyle(theme.accent)
                .lineLimit(1)
        }
    }

    private func accessibilityText(showsArabic: Bool) -> String {
        let arabic = showsArabic ? day.texts.joined(separator: " ") + ". " : ""
        return arabic + day.spokenReference(style)
    }
}

#if os(iOS)
/// The Lock Screen rectangle: the Arabic in Hafs, or the reference alone if it is not registered.
struct AyahOfTheDayAccessoryView: View {
    let day: QuranWidgetSnapshot.DailyAyah
    let style: NextPrayerSnapshot.Style
    let hasHafs: Bool

    var body: some View {
        let showsArabic = hasHafs && QuranWidgetFontRegistration.register()
        VStack(alignment: .leading, spacing: 1) {
            if showsArabic {
                QuranWidgetArabicText(texts: day.texts, firstVerse: day.first.verse, size: 14, lineLimit: 3)
            }

            Text(day.referenceText(style))
                .appFont(showsArabic ? .caption : .headline)
                .lineLimit(2)
        }
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            (showsArabic ? day.texts.joined(separator: " ") + ". " : "") + day.spokenReference(style)
        )
    }
}
#endif

/// The ayah's Arabic, drawn and never edited.
///
/// Each stored string is given to `QuranAyahText.attributed` unchanged (it only names a fallback
/// font on the few ranges Hafs cannot draw), followed by a no-break space and the end marker
/// the app draws too. The caller must only show this when the Hafs face registered: this view
/// never lets the system face draw Quran text on purpose.
struct QuranWidgetArabicText: View {
    let texts: [String]
    let firstVerse: Int
    let size: CGFloat
    let lineLimit: Int

    var body: some View {
        Text(composed)
            .font(.custom(QuranWidgetFont.postScriptName, size: size, relativeTo: .body))
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Applied last so `.leading` is resolved as right-to-left: the block sits on the right
            // in both UI languages.
            .environment(\.layoutDirection, .rightToLeft)
    }

    private var composed: AttributedString {
        var result = AttributedString()
        for (index, text) in texts.enumerated() {
            if index > 0 { result += AttributedString(" ") }
            result += QuranAyahText.attributed(text, face: .kfgqpcHafs, scaledSize: size, hafsIsRegistered: true)
            result += AttributedString("\u{00A0}")
            result += AttributedString(AyahEndMarker.text(verse: firstVerse + index))
        }
        return result
    }
}
