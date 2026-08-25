//
//  SearchResultRow.swift
//  ThawabForGod
//

import SwiftUI

/// One verse a search turned up: where it is, and enough of it to recognise.
///
/// Unlike `BookmarkRow`, which shows only a reference, this shows the text — a bookmark is a place
/// the reader chose and already knows, while a result is one they are deciding about, and a list
/// of bare references would make them open each in turn to find out which they meant.
///
/// Nothing is highlighted, and that is not an omission. The index is built over a *folded* copy of
/// the verse — no diacritics, and one spelling per letter — so a match's position in the indexed
/// string does not correspond to a position in the vowelled Uthmani text drawn here. A highlight
/// computed there would land on the wrong letters.
struct SearchResultRow: View {
    let verse: Verse
    let surah: Surah?
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                reference
                text
            }
            .padding(AppSpacing.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
                .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// "Al-Baqara · Verse 255", in the reader's language and digits.
    private var reference: some View {
        HStack(spacing: 6) {
            Text(surah?.arabicName ?? "")
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(verbatim: "·")

            Text(l10n.string(.quranVerseLabel))
            Text(l10n.string(verse.number, grouped: false))
        }
        .appFont(.caption, weight: .medium)
        .foregroundStyle(theme.textSecondary)
    }

    /// The verse itself, cut off after three lines.
    ///
    /// Three rather than all of it: 2:282 is a page on its own, and a result list where one entry
    /// fills the screen is one the reader has to scroll past rather than scan. The whole verse is
    /// one tap away, which is what the row is for.
    private var text: some View {
        Text(verse.text)
            .appFont(.body)
            .foregroundStyle(theme.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Arabic whatever the interface language is — the same reasoning as `VerseRow`. An
            // English reader's left-aligned paragraph would hang from the wrong edge, which the
            // bidi algorithm has nothing to say about.
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, AppLanguage.arabic.locale)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    SearchResultRow(
        verse: Verse(
            id: VerseReference(surah: 2, verse: 255),
            text: "ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ",
            juz: 3,
            hizb: 5,
            rubElHizb: 17,
            page: 42,
            sajda: nil
        ),
        surah: Surah(
            id: 2,
            arabicName: "البقرة",
            transliteration: "Al-Baqara",
            englishName: "The Cow",
            verseCount: 286,
            revelationPlace: .medinan,
            revelationOrder: 87,
            bismillah: nil
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
