//
//  VerseRow.swift
//  ThawabForGod
//

import SwiftUI

/// One verse, as it is read.
///
/// The number is set *inside the text* between ornate parentheses — `﴿٢٥٥﴾` — rather than beside
/// it in a badge, because that is where the mushaf puts it and because a marker that flows with
/// the paragraph keeps its place when the text wraps. `Text` concatenation is what makes that a
/// single laid-out paragraph rather than two views that only look like one.
struct VerseRow: View {
    let verse: Verse

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            text

            if let sajda = verse.sajda {
                sajdaMarker(sajda)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Forced right-to-left rather than left to inherit the screen's direction — the same
        // reasoning as `DhikrCard`. The verse is Arabic whatever the interface language is, and
        // an English reader's left-aligned paragraph would hang from the wrong edge. The bidi
        // algorithm orders the *characters* correctly but has nothing to say about that.
        .environment(\.layoutDirection, .rightToLeft)
        // So VoiceOver reads it in Arabic rather than in the interface's voice.
        .environment(\.locale, AppLanguage.arabic.locale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var text: some View {
        (
            Text(verse.text)
                + Text(verbatim: " ﴿")
                + Text(l10n.string(verse.number, grouped: false))
                + Text(verbatim: "﴾")
        )
        .appFont(.title3)
        .foregroundStyle(theme.textPrimary)
        .lineSpacing(14)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The place-of-prostration mark, and the word for it.
    ///
    /// Both kinds are drawn the same way. Which of them obliges a prostration is a question the
    /// schools answer differently, and the corpus keeps them apart precisely so that a later
    /// slice can act on the difference rather than have it already flattened here.
    private func sajdaMarker(_ sajda: Sajda) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "۩")
            Text(l10n.string(.quranSajda))
        }
        .appFont(.caption, weight: .medium)
        .foregroundStyle(theme.accent)
    }

    /// Spoken as "verse 255", then the verse — so the reference comes before the recitation
    /// rather than trailing it as the ornate parentheses would have VoiceOver do.
    private var accessibilityLabel: String {
        "\(l10n.string(.quranVerseLabel)) \(l10n.string(verse.number, grouped: false)). \(verse.text)"
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VerseRow(
        verse: Verse(
            id: VerseReference(surah: 2, verse: 255),
            text: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            juz: 3,
            hizb: 5,
            rubElHizb: 17,
            page: 42,
            sajda: nil
        )
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
