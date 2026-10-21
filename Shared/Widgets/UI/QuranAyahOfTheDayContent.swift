//
//  QuranAyahOfTheDayContent.swift
//  ThawabForGod
//

import SwiftUI

/// The Ayah of the Day, drawn for one family. Content only: the tap target and the container
/// background belong to the widget extension, so a test can render this without WidgetKit.
///
/// **Fitting is a ladder, not a limit.** Each family tries a list of steps from the most generous
/// to the tightest and `ViewThatFits` takes the first that fits the height, so the Arabic is
/// never cut while a smaller size or a dropped translation would have saved it. Only the medium
/// family's last step truncates, with an ellipsis, because a long ayah cannot be both whole and
/// legible in that height. The stored text is only ever drawn, never edited.
struct QuranAyahOfTheDayContent: View {

    let entry: QuranWidgetEntry
    let family: QuranWidgetFamily

    @Environment(\.theme) private var theme

    private var style: NextPrayerSnapshot.Style { entry.style }
    private var l10n: WidgetLocalization { WidgetLocalization(style) }

    /// Registered in this process, now: a held entry may be rendered where the timeline build never ran.
    private var canDrawArabic: Bool { entry.hasHafs && QuranWidgetFontRegistration.registerOnce() }

    /// One rung of the ladder.
    private struct Step {
        var arabicSize: CGFloat
        /// Nil lets the Arabic take every line it needs; a number truncates with an ellipsis.
        var arabicLimit: Int?
        var showsTranslation: Bool
        var translationLimit: Int?
    }

    private static let largeSteps: [Step] = [
        Step(arabicSize: 24, arabicLimit: nil, showsTranslation: true, translationLimit: nil),
        Step(arabicSize: 22, arabicLimit: nil, showsTranslation: true, translationLimit: nil),
        Step(arabicSize: 20, arabicLimit: nil, showsTranslation: true, translationLimit: 6),
        Step(arabicSize: 20, arabicLimit: nil, showsTranslation: true, translationLimit: 3),
        Step(arabicSize: 18, arabicLimit: nil, showsTranslation: true, translationLimit: 2),
        Step(arabicSize: 18, arabicLimit: nil, showsTranslation: false, translationLimit: nil),
        Step(arabicSize: 16, arabicLimit: nil, showsTranslation: false, translationLimit: nil)
    ]

    private static let mediumSteps: [Step] = [
        Step(arabicSize: 20, arabicLimit: nil, showsTranslation: false, translationLimit: nil),
        Step(arabicSize: 18, arabicLimit: nil, showsTranslation: false, translationLimit: nil),
        Step(arabicSize: 16, arabicLimit: 3, showsTranslation: false, translationLimit: nil)
    ]

    var body: some View {
        if let day = entry.snapshot?.dailyAyah(for: entry.date) {
            let showsArabic = canDrawArabic
            filled(day: day, showsArabic: showsArabic)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(day, showsArabic: showsArabic))
        } else {
            QuranWidgetEmptyView(key: .quranWidgetAyahEmpty, style: style)
        }
    }

    @ViewBuilder
    private func filled(day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> some View {
        switch family {
        case .rectangular:
            accessory(day, showsArabic: showsArabic)
        case .large:
            ladder(Self.largeSteps, day: day, showsArabic: showsArabic)
        case .small, .medium:
            ladder(Self.mediumSteps, day: day, showsArabic: showsArabic)
        }
    }

    // MARK: - Ladder

    private func ladder(_ steps: [Step], day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> some View {
        // Without the face the reference is the whole content; there is nothing to step down.
        let rungs = showsArabic ? steps : [steps[steps.count - 1]]
        return ViewThatFits(in: .vertical) {
            ForEach(rungs.indices, id: \.self) { index in
                let step = rungs[index]
                rung(step, day: day, showsArabic: showsArabic)
                    .fixedSize(horizontal: false, vertical: step.arabicLimit == nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rung(_ step: Step, day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            header(day, showsArabic: showsArabic)

            if showsArabic {
                QuranWidgetArabicText(
                    texts: day.texts,
                    firstVerse: day.first.verse,
                    size: step.arabicSize,
                    lineLimit: step.arabicLimit
                )
                .foregroundStyle(theme.textPrimary)
            } else {
                Text(referenceText(day))
                    .appFont(.title3, weight: .semibold)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
            }

            if showsArabic, step.showsTranslation, let translation = day.translation, !translation.texts.isEmpty {
                translationBlock(translation, lines: step.translationLimit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// "Ayah of the day" on one side, the reference on the other.
    private func header(_ day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text(l10n.string(.quranWidgetAyahName))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.accent)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.xs)

            if showsArabic {
                Text(referenceText(day))
                    .appFont(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    /// Every ayah of a range, in order, in the translation's own direction.
    private func translationBlock(_ translation: QuranWidgetSnapshot.Translation, lines: Int?) -> some View {
        let direction: LayoutDirection = translation.isRightToLeft ? .rightToLeft : .leftToRight
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: translation.texts.joined(separator: " "))
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(lines)
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

    // MARK: - Lock Screen

    /// The rectangle: the Arabic in Hafs, or the reference alone if it is not registered.
    private func accessory(_ day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if showsArabic {
                QuranWidgetArabicText(texts: day.texts, firstVerse: day.first.verse, size: 14, lineLimit: 3)
            }

            Text(referenceText(day))
                .appFont(showsArabic ? .caption : .headline)
                .lineLimit(2)
        }
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Text

    private func referenceText(_ day: QuranWidgetSnapshot.DailyAyah) -> String {
        let name = style.surahName(arabic: day.surahNameArabic, english: day.surahNameEnglish)
        return "\(name) \(l10n.reference(surah: day.first.surah, verse: day.first.verse, lastVerse: day.lastVerse))"
    }

    private func spokenReference(_ day: QuranWidgetSnapshot.DailyAyah) -> String {
        let name = style.surahName(arabic: day.surahNameArabic, english: day.surahNameEnglish)
        if day.lastVerse > day.first.verse {
            return l10n.string(
                .quranWidgetAyahRangeLabel, name, l10n.number(day.first.verse), l10n.number(day.lastVerse)
            )
        }
        return l10n.string(.quranWidgetAyahLabel, name, l10n.number(day.first.verse))
    }

    private func accessibilityText(_ day: QuranWidgetSnapshot.DailyAyah, showsArabic: Bool) -> String {
        let arabic = showsArabic ? day.texts.joined(separator: " ") + ". " : ""
        return arabic + spokenReference(day)
    }
}

/// The ayah's Arabic, drawn and never edited.
///
/// Each stored string is given to `QuranAyahText.attributed` unchanged (it only names a fallback
/// font on the few ranges Hafs cannot draw), followed by a no-break space and the end marker
/// the app draws too. The caller must only show this when the Hafs face registered: this view
/// never lets the system face draw Quran text on purpose. The size is a fixed point size on
/// purpose: the widget's box does not grow with Dynamic Type, so neither may the words in it.
struct QuranWidgetArabicText: View {
    let texts: [String]
    let firstVerse: Int
    let size: CGFloat
    /// Nil is "as many lines as it takes".
    let lineLimit: Int?

    var body: some View {
        Text(composed)
            .font(.custom(QuranWidgetFont.postScriptName, fixedSize: size))
            .lineLimit(lineLimit)
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

extension View {
    /// The theme, the locale carrying the digits and the layout direction, in that order. The
    /// widget adds its tap target and background after this.
    func quranWidgetTheme(style: NextPrayerSnapshot.Style) -> some View {
        modifier(QuranWidgetThemeModifier(style: style))
    }
}

private struct QuranWidgetThemeModifier: ViewModifier {
    let style: NextPrayerSnapshot.Style

    func body(content: Content) -> some View {
        content
            .environment(\.theme, Theme(accent: style.accent))
            .environment(\.locale, WidgetLocalization(style).locale)
            .environment(\.layoutDirection, style.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}
