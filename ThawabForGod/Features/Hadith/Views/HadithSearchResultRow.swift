//
//  HadithSearchResultRow.swift
//  ThawabForGod
//

import SwiftUI

/// One narration as a search result: where it is, then as much of it as fits.
///
/// The citation leads and names the collection, which the reading screen's card does not need to
/// — a search runs across both Sahihs, so "No. 1" alone would be ambiguous between two narrations
/// in a way it never is inside a kitab.
///
/// **Nothing is highlighted**, and that is deliberate rather than unfinished. The index is over
/// the folded text — no diacritics, one spelling per letter — so a match's offsets do not
/// correspond to positions in the vowelled text drawn here. The same reason the Quran's results
/// carry no highlight.
struct HadithSearchResultRow: View {
    let hadith: Hadith
    let collection: String
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    /// How much of a narration a result shows.
    ///
    /// Long enough to recognise the narration by, short enough that fifty of them are a list
    /// rather than a chapter. A character count rather than a line limit because the row has to
    /// be the same height whatever the Dynamic Type setting does to it — and because a narration
    /// opens with its isnad, so the first line is chain of transmission rather than subject, and
    /// three lines is roughly where the words the reader searched for start to appear.
    private static let excerpt = 220

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                citation

                Text(text)
                    .appFont(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .environment(\.locale, AppLanguage.arabic.locale)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The narration, cut to `excerpt` characters on a word boundary.
    ///
    /// Cut here rather than in the repository: what fits on a row is a fact about this view, and a
    /// repository that returned truncated text would have made the decision for every future
    /// caller, including a screen that wants the whole thing.
    private var text: String {
        guard hadith.text.count > Self.excerpt else { return hadith.text }

        let cut = hadith.text.prefix(Self.excerpt)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return cut[..<end] + "…"
    }

    /// `صحيح البخاري · No. 1`, with the collection first.
    private var citation: some View {
        HStack(spacing: 6) {
            Text(collection)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(verbatim: "·")

            HStack(spacing: 6) {
                Text(l10n.string(.hadithNumberLabel))
                Text(l10n.string(hadith.reference.first, grouped: false))
            }
        }
        .appFont(.caption, weight: .semibold)
        .foregroundStyle(theme.accent)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    HadithSearchResultRow(
        hadith: Hadith(
            id: HadithID(collection: "bukhari", number: 1),
            bookNumber: 1,
            reference: HadithReference(collection: "bukhari", first: 1),
            text: "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى"
        ),
        collection: "صحيح البخاري",
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
