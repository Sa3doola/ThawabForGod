//
//  BookmarkRow.swift
//  ThawabForGod
//

import SwiftUI

/// One kept verse in the bookmarks list: which chapter it is in, and where.
///
/// It shows the *reference* rather than the verse text. A bookmarks list made of full verses
/// would be a second reading screen with none of the reading screen's controls, and a saved place
/// is a place — the reason to open this list is to go back to it, not to read it here.
///
/// The chapter's name is passed in rather than looked up: this row has no repository and no
/// business acquiring one, and the list above it already holds all 114 chapters.
struct BookmarkRow: View {
    let bookmark: QuranBookmark
    let surah: Surah?
    let action: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "bookmark.fill")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.accent)

                names
                Spacer(minLength: 8)

                Image(systemName: "chevron.forward")
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(surah?.arabicName ?? "")
                .appFont(.body, weight: .medium)
                .foregroundStyle(theme.textPrimary)
                .environment(\.locale, AppLanguage.arabic.locale)

            Text(verseLabel)
                .appFont(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// "Verse 255" rather than "2:255" — the chapter is named on the line above, so repeating its
    /// number here would say the same thing twice. Both digits go through `LocalizationManager`,
    /// never interpolation.
    private var verseLabel: String {
        "\(l10n.string(.quranVerseLabel)) \(l10n.string(bookmark.reference.verse, grouped: false))"
    }
}
