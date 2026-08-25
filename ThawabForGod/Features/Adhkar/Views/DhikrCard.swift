//
//  DhikrCard.swift
//  ThawabForGod
//

import SwiftUI

/// One dhikr, as it is read: which one it is, the Arabic first and largest, then whatever the
/// reader has asked to see alongside it, then where it comes from.
///
/// **The counter is no longer in here.** It used to sit at the foot of every card in a scrolling
/// column, which meant the control the reader taps a hundred times moved with the text — and on a
/// long dhikr it was below the fold, so counting meant scrolling. The reading screen now shows one
/// card at a time and pins the counter under it, so the thumb has one place to be for the whole
/// category. See `AdhkarReadingView`.
///
/// Like `RepeatCounter`, it takes values rather than a view model — the reading screen owns the
/// state, and this stays a thing that can be previewed in any of its shapes.
struct DhikrCard: View {
    let dhikr: Dhikr
    /// Its position in the category, for the kicker. `nil` where the card is shown out of any
    /// sequence, which is every use but the reader.
    var position: Int?
    let counted: Int
    let showsTranslation: Bool
    let showsTransliteration: Bool

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    private var isComplete: Bool { counted >= dhikr.repeatCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let position {
                kicker(position)
            }

            arabicText

            if showsTransliteration, let transliteration = dhikr.transliteration {
                secondaryText(transliteration, style: .callout, italic: true)
            }

            if showsTranslation, let translation = dhikr.translation {
                secondaryText(translation, style: .body, italic: false)
            }

            if let virtue = dhikr.virtue {
                virtueBlock(virtue)
            }

            reference
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .strokeBorder(isComplete ? theme.success : .clear, lineWidth: 1.5)
        }
        .animation(.snappy, value: isComplete)
    }

    /// `DHIKR 4` — which of the category's adhkar this is.
    ///
    /// The screen's pips say the same thing as a shape and the toolbar says it as a fraction;
    /// this says it in words, which is the form that survives being read aloud by VoiceOver and
    /// the one a reader can use to find their place again after a phone call.
    private func kicker(_ position: Int) -> some View {
        Text(l10n.string(.adhkarDhikrNumber, l10n.string(position, grouped: false)))
            .appFont(.caption, weight: .semibold)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(theme.textSecondary)
    }

    /// The dhikr itself.
    ///
    /// Forced right-to-left rather than left to inherit the screen's direction. The text is
    /// Arabic whatever language the interface is in, and an English reader's left-aligned
    /// paragraph would start every line on the wrong edge — the bidi algorithm gets the
    /// *characters* right but has nothing to say about which edge a paragraph hangs from.
    /// Under this environment `.leading` resolves to the right in both interface languages.
    private var arabicText: some View {
        Text(dhikr.arabicText)
            .appFont(.title3)
            .foregroundStyle(theme.textPrimary)
            .lineSpacing(10)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            // Arabic is not the interface language for every reader, and VoiceOver would
            // otherwise read it in whatever voice the interface is set to.
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    private func secondaryText(_ text: String, style: AppTextStyle, italic: Bool) -> some View {
        Text(text)
            .appFont(style)
            .italic(italic)
            .foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func virtueBlock(_ virtue: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.string(.adhkarVirtueLabel))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.accent)

            Text(virtue)
                .appFont(.footnote)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(theme.accent.opacity(0.08), in: .rect(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .combine)
    }

    /// Where the dhikr comes from, printed rather than summarised.
    ///
    /// This line is the whole reason the corpus stores a citation: the text has not been checked
    /// against a printed Hisn al-Muslim yet (see `Resources/Corpus/README.md`), so a reader must
    /// be able to go and look rather than take the app's word for it.
    private var reference: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.string(.adhkarSourceLabel))
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(theme.textSecondary)

            Text(dhikr.reference)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    ScrollView {
        DhikrCard(
            dhikr: Dhikr(
                id: 1,
                arabicText: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
                translation: "Glory is to Allah and praise is to Him.",
                transliteration: "Subḥāna-llāhi wa biḥamdih.",
                reference: "Muslim 2692.",
                virtue: "Whoever says this one hundred times in a day has his sins forgiven.",
                repeatCount: 100
            ),
            position: 4,
            counted: 3,
            showsTranslation: true,
            showsTransliteration: true
        )
        .padding()
    }
    .themed(ThemeManager(settingsStore: settingsStore))
    .localized(
        LocalizationManager(
            settingsStore: settingsStore,
            numberFormatting: LocaleNumberFormattingService(),
            timeFormatting: LocaleTimeFormattingService()
        )
    )
}
