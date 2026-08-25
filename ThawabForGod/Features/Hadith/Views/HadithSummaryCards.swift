//
//  HadithSummaryCards.swift
//  ThawabForGod
//

import SwiftUI

/// What the reader has built in this tab, as two cards across the top: the review deck, and what
/// they have kept.
///
/// **A pair rather than the full-width row this replaces.** The two numbers are the same *kind* of
/// number — a count of things the reader has chosen to hold on to — and setting them side by side
/// is what says so. It also buys the screen back a card's worth of height above the collections,
/// which are the tab's actual subject and were being pushed down by a row that is mostly padding.
///
/// Either card is absent until there is something to put in it, which is the rule the review row
/// already followed and the reason the pair is built from whichever halves exist rather than from
/// a fixed two: a card offering to review nothing is an invitation the app cannot honour, and a
/// bookmarks card reading `0` is a fault report about the reader.
struct HadithSummaryCards: View {
    let dueCount: Int
    let deckCount: Int
    let bookmarkCount: Int
    let bookmarkedBookCount: Int

    let review: () -> Void
    let showBookmarks: () -> Void

    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var hasDeck: Bool { deckCount > 0 }
    private var hasBookmarks: Bool { bookmarkCount > 0 }

    var body: some View {
        // At an accessibility size two cards on one line is two columns of single words, so the
        // pair unstacks — the same answer `DayPrayerRow` gives, for the same reason.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: AppSpacing.md))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))

        if hasDeck || hasBookmarks {
            layout {
                if hasDeck {
                    SummaryCard(
                        symbol: dueCount > 0 ? "brain.head.profile.fill" : "checkmark",
                        tint: dueCount > 0 ? theme.accent : theme.success,
                        kicker: l10n.string(.hadithMemorizeTitle),
                        headline: dueLabel,
                        detail: l10n.string(.hadithDeckSize, l10n.string(deckCount)),
                        action: review
                    )
                }

                if hasBookmarks {
                    SummaryCard(
                        symbol: "bookmark.fill",
                        tint: theme.accent,
                        kicker: l10n.string(.hadithBookmarksSection),
                        headline: l10n.string(.hadithBookmarksSaved, l10n.string(bookmarkCount)),
                        detail: l10n.string(.hadithBookmarksAcross, l10n.string(bookmarkedBookCount)),
                        action: showBookmarks
                    )
                }
            }
        }
    }

    /// `3 due`, or "nothing today" when the deck is caught up.
    ///
    /// Both are worth saying, and they are not the same sentence. A reader who has finished for
    /// the day has *done* something; a card that simply showed `0` would read like a fault.
    private var dueLabel: String {
        dueCount > 0
            ? l10n.string(.hadithMemorizeDue, l10n.string(dueCount))
            : l10n.string(.hadithMemorizeCaughtUp)
    }
}

/// One of the two: a symbol, a kicker, a figure, and a line under it.
///
/// Both halves are the same view so the two cards cannot drift apart in padding or type — the
/// thing that makes a pair read as a pair is that nothing distinguishes them but their words.
private struct SummaryCard: View {
    let symbol: String
    let tint: Color
    let kicker: String
    let headline: String
    let detail: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Image(systemName: symbol)
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(kicker)
                        .appFont(.caption, weight: .semibold)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(theme.textSecondary)

                    Text(headline)
                        .appFont(.headline)
                        .foregroundStyle(theme.textPrimary)

                    Text(detail)
                        .appFont(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(AppSpacing.row)
            // Equal heights whichever card has the longer word in it: without this the taller
            // one sets the row and the shorter sits in a box with a gap under it.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .appCard()
            .appHover()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let settingsStore = InMemorySettingsStore()

    VStack(spacing: 12) {
        HadithSummaryCards(
            dueCount: 14,
            deckCount: 38,
            bookmarkCount: 32,
            bookmarkedBookCount: 5,
            review: {},
            showBookmarks: {}
        )

        HadithSummaryCards(
            dueCount: 0,
            deckCount: 38,
            bookmarkCount: 0,
            bookmarkedBookCount: 0,
            review: {},
            showBookmarks: {}
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
