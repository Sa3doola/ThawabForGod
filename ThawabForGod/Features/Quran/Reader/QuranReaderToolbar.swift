//
//  QuranReaderToolbar.swift
//  ThawabForGod
//

import SwiftUI

/// The reader's toolbar.
///
/// **The final layout**, so each later task knows where its button goes: Library leading, at every
/// width, replacing the system back button (in Noor the Library is the tab's root, so "Library" and
/// "back" are one action); on the trailing side, Search (M5.5, every width), then reader settings
/// (M5.6) and bookmarks (M6), which move into a More menu (`ellipsis`) at compact width together
/// with the mode toggle once that menu has a second item. A button is written in the task that
/// makes its destination work, so today there are two: Library, and the mode toggle where the build
/// has Mushaf pages. The toggle is shown directly at every width because a menu of one item is a
/// control nobody can choose from.
struct QuranReaderToolbar: ToolbarContent {
    let viewModel: QuranReaderViewModel
    let coordinator: QuranCoordinator
    let userData: QuranUserDataStore
    /// A page colour: the bar is the page's while the reader is in front.
    let tint: Color
    /// Compact width: the mode toggle and the settings button share a More menu.
    let isCompact: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                coordinator.popToRoot()
            } label: {
                QuranToolbarLabel(key: .quranLibrary, systemImage: "books.vertical")
            }
            .tint(tint)
            .accessibilityIdentifier("quran.reader.library")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator.showSearch()
            } label: {
                QuranToolbarLabel(key: .quranSearch, systemImage: "magnifyingglass")
            }
            .tint(tint)
            .accessibilityIdentifier("quran.reader.search")
        }
        if viewModel.showsMushafPages {
            ToolbarItem(placement: .primaryAction) {
                QuranPageBookmarkButton(viewModel: viewModel, userData: userData, tint: tint)
            }
        }
        if isCompact, viewModel.canSwitchDisplayMode {
            // At compact width the two secondary actions share one menu.
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    displayModeButton
                    settingsButton
                } label: {
                    QuranToolbarLabel(key: .quranMore, systemImage: "ellipsis")
                }
                .tint(tint)
                .accessibilityIdentifier("quran.reader.more")
            }
        } else {
            // Wide, or compact with nothing to share a menu with (the public build has no second mode).
            if viewModel.canSwitchDisplayMode {
                ToolbarItem(placement: .primaryAction) {
                    displayModeButton
                }
            }
            ToolbarItem(placement: .primaryAction) {
                settingsButton
            }
        }
    }

    private var settingsButton: some View {
        Button {
            coordinator.showSettings()
        } label: {
            QuranToolbarLabel(key: .readerOptionsTitle, systemImage: "textformat.size")
        }
        .tint(tint)
        .accessibilityIdentifier("quran.reader.settings")
    }

    private var displayModeButton: some View {
        Button {
            viewModel.toggleDisplayMode()
        } label: {
            if viewModel.showsMushafPages {
                QuranToolbarLabel(key: .quranShowSeparated, systemImage: "list.bullet")
            } else {
                QuranToolbarLabel(key: .quranShowMushaf, systemImage: "book")
            }
        }
        .tint(tint)
        .accessibilityIdentifier("quran.reader.modeToggle")
    }
}

/// Bookmarks the Mushaf page on screen, by its first ayah.
///
/// The anchor is the first ayah that *starts* on the page, so a page opening mid-ayah toggles the
/// next one and never touches an ayah bookmarked from the panel; a page with none starting on it
/// (a build without page numbers) falls back to the first ayah drawn there. It reads the page and
/// the store in its own `body`, so a page turn or a mark redraws this button and nothing above it.
private struct QuranPageBookmarkButton: View {
    let viewModel: QuranReaderViewModel
    let userData: QuranUserDataStore
    let tint: Color

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        let anchor = anchorAyah
        let isBookmarked = anchor.map { userData.isBookmarked($0) } ?? false
        Button {
            if let anchor { userData.toggleBookmark(anchor) }
        } label: {
            Label(
                isBookmarked
                    ? l10n.string(.quranPageBookmarkRemove)
                    : l10n.string(.quranPageBookmarkAdd),
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            )
        }
        .tint(tint)
        .disabled(anchor == nil)
        .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked) { old, new in !old && new }
        .accessibilityIdentifier("quran.reader.pageBookmark")
    }

    private var anchorAyah: VerseReference? {
        guard let corpus = viewModel.corpus else { return nil }
        let number = viewModel.mushaf.page
        guard let page = corpus.page(number) else { return nil }
        return page.ayahs.first { corpus.pageNumber(for: $0) == number } ?? page.firstAyah
    }
}

/// A toolbar button's label, drawn as a view so it can read the localization environment.
///
/// `ToolbarContent` is not a view and nothing in the app reads the environment from one, so the
/// lookup happens here, in a view that SwiftUI builds inside the toolbar.
private struct QuranToolbarLabel: View {
    let key: L10nKey
    let systemImage: String

    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Label(l10n.string(key), systemImage: systemImage)
    }
}
