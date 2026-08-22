//
//  HadithCard.swift
//  ThawabForGod
//

import SwiftUI

/// One narration: the reference it is cited by, then the text.
///
/// Like `DhikrCard`, it takes a value rather than a view model — the reading screen owns the
/// state, and this stays a thing that can be previewed in any of its shapes.
///
/// The reference leads rather than follows. A hadith is a quotation, and where it is quoted from
/// is what makes it checkable; putting it underneath would make it a footnote to text the reader
/// has already taken on the app's word.
struct HadithCard: View {
    let hadith: Hadith
    let isBookmarked: Bool
    let isMemorizing: Bool
    let onBookmark: () -> Void
    let onMemorize: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                reference

                Spacer(minLength: 12)

                memorizeButton
                bookmarkButton
            }

            text
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 16))
        // `.contain` rather than `.combine`, so the bookmark button stays a separate element
        // VoiceOver can reach. Combining would fold it into the narration and leave a reader
        // with a very long label and no way to act on it.
        .accessibilityElement(children: .contain)
    }

    /// Keeps the narration, or forgets it.
    ///
    /// A filled bookmark when kept and an outline when not — the same pair the Quran's reader
    /// uses, and the one convention iOS readers already know. The label changes with it rather
    /// than staying "Bookmark", because what the button will *do* is the thing VoiceOver has to
    /// announce.
    private var bookmarkButton: some View {
        Button(action: onBookmark) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .appFont(.footnote)
                .foregroundStyle(isBookmarked ? theme.accent : theme.textSecondary)
                // A tap target the finger can find, without the icon growing to match it.
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            l10n.string(isBookmarked ? .hadithBookmarkRemove : .hadithBookmarkAdd)
        )
    }

    /// Puts the narration in the review deck, or takes it out.
    ///
    /// **A second mark beside the bookmark, not the same one.** A bookmark is a ribbon — come
    /// back to this — while memorizing is a commitment to be asked about it every few days.
    /// Folding them together would put every kept narration into the review queue, which is the
    /// fastest way to make a reader stop keeping things.
    private var memorizeButton: some View {
        Button(action: onMemorize) {
            Image(systemName: isMemorizing ? "brain.head.profile.fill" : "brain.head.profile")
                .appFont(.footnote)
                .foregroundStyle(isMemorizing ? theme.accent : theme.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            l10n.string(isMemorizing ? .hadithMemorizeStop : .hadithMemorizeStart)
        )
    }

    /// The narration itself.
    ///
    /// Forced right-to-left rather than left to inherit the screen's direction, for the reason
    /// `DhikrCard` gives: the text is Arabic whatever language the interface is in, and an
    /// English reader's left-aligned paragraph would start every line on the wrong edge. The
    /// locale goes with it so VoiceOver reads it in an Arabic voice rather than the interface's.
    private var text: some View {
        Text(hadith.text)
            .appFont(.body)
            .foregroundStyle(theme.textPrimary)
            .lineSpacing(10)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLanguage.arabic.locale)
    }

    /// `1` — or `5709–5712` for the few hundred published under several numbers at once.
    ///
    /// Pinned left-to-right, like `JuzRow`'s span: a range reads low-to-high in both languages,
    /// and under an Arabic layout the bidi algorithm would otherwise swap the two numbers around
    /// the dash and say the narration runs from 5712 to 5709.
    private var reference: some View {
        HStack(spacing: 6) {
            Text(l10n.string(.hadithNumberLabel))

            HStack(spacing: 3) {
                Text(l10n.string(hadith.reference.first, grouped: false))

                if hadith.reference.isSpan {
                    Text(verbatim: "–")
                    Text(l10n.string(hadith.reference.last, grouped: false))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .appFont(.caption, weight: .semibold)
        .foregroundStyle(theme.accent)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 14) {
        HadithCard(
            hadith: Hadith(
                id: HadithID(collection: "bukhari", number: 1),
                bookNumber: 1,
                reference: HadithReference(collection: "bukhari", first: 1),
                text: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى"
            ),
            isBookmarked: false,
            isMemorizing: false,
            onBookmark: {},
            onMemorize: {}
        )

        HadithCard(
            hadith: Hadith(
                id: HadithID(collection: "bukhari", number: 5709),
                bookNumber: 76,
                reference: HadithReference(collection: "bukhari", first: 5709, last: 5712),
                text: "لاَ عَدْوَى وَلاَ طِيَرَةَ وَلاَ هَامَةَ وَلاَ صَفَرَ"
            ),
            isBookmarked: true,
            isMemorizing: true,
            onBookmark: {},
            onMemorize: {}
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
