//
//  DhikrCard.swift
//  ThawabForGod
//

import SwiftUI

/// One dhikr, as it is read: which one it is, and then the words.
///
/// **It is almost entirely one paragraph of Arabic now**, and that is the corpus rather than a
/// simplification. The 34 rows this feature began with carried an English translation, a
/// transliteration, a reported virtue and a hadith citation; Hisn al-Muslim's own text carries
/// none of those, so a card that kept their labelled blocks would draw four empty frames. What
/// took their place is size: the text is set at a point size the reader chooses, on the reading
/// font, because with nothing else on the card there is no reason for it to be small.
///
/// The card also stopped being the thing that reports completion. It used to take a green border
/// when its counter finished, which on a pager is a border the reader sees for the half second
/// before the card leaves the screen. The pips above and the counter below both say it, in places
/// that stay put.
///
/// Like `RepeatCounter`, it takes values rather than a view model — the reading screen owns the
/// state, and this stays a thing that can be previewed in any of its shapes.
struct DhikrCard: View {
    let dhikr: Dhikr
    /// Its position in the chapter, for the kicker. `nil` where the card is shown out of any
    /// sequence, or in a chapter of one, where "dhikr 1 of 1" is a label about nothing.
    var position: Int?
    /// The point size the reader has chosen. Dynamic Type still multiplies it — see
    /// `ReadingFontModifier`.
    var textSize: Double = ReaderTypography.fallback.textSize

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let position {
                kicker(position)
            }

            arabicText

            if dhikr.repeatCount > 1 {
                repeatBadge
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        // **No `.textSelection(.enabled)` here, and it is worth saying why so nobody adds it
        // back.** Copying a dhikr into a message is an obvious thing to want, but a selectable
        // `Text` reports its natural width instead of taking the one it is given — anywhere on
        // this card, on the paragraph or on the stack around it — and inside the pager that
        // collapses each page to about half the screen and clips the words at both edges.
        // Verified on device both ways. If selection is wanted later it needs a different
        // mechanism, not this modifier.
    }

    /// `DHIKR 4` — which of the chapter's adhkar this is.
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
            // Amiri, pinned, whatever face the Quran reader chose. The book is in modern spelling
            // with modern punctuation — آ, ﴿ ﴾, commas and full stops — and the KFGQPC face is
            // encoded for the Uthmani text alone, with no glyph for any of those. The leading
            // comes with the face and is proportional to the size, since Arabic's marks that are
            // comfortable at 20pt collide at 40.
            .readingFont(size: textSize, face: .amiriQuran)
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            // Arabic is not the interface language for every reader, and VoiceOver would
            // otherwise read it in whatever voice the interface is set to.
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    /// `× 100` — how many times the book says to say it.
    ///
    /// On the card as well as on the counter, because the two answer different questions. The
    /// counter says how many are left *now*; this says what the dhikr asks for, which is the part
    /// a reader wants to see before they start and again when they page back to it.
    private var repeatBadge: some View {
        Text(l10n.string(.adhkarOfTotal, l10n.string(dhikr.repeatCount, grouped: false)))
            .appFont(.footnote, weight: .semibold)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(theme.accent.opacity(0.12), in: .rect(cornerRadius: AppRadius.sm))
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    ScrollView {
        VStack(spacing: 16) {
            DhikrCard(
                dhikr: Dhikr(
                    id: 1017,
                    arabicText: "((سُبْحَانَ اللَّهِ وَبِحَمْدِهِ)) (مائة مرَّةٍ).",
                    repeatCount: 100
                ),
                position: 17
            )

            DhikrCard(
                dhikr: Dhikr(
                    id: 98001,
                    arabicText: """
                        ((بِسْمِ اللَّهِ، اللَّهُمَّ إِنِّي أَسْأَلُكَ خَيْرَ هَذِهِ السُّوقِ وَخَيْرَ مَا فِيهَا، \
                        وَأَعُوذُ بِكَ مِنْ شَرِّهَا وَشَرِّ مَا فِيهَا)).
                        """,
                    repeatCount: 1
                ),
                textSize: 26
            )
        }
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
