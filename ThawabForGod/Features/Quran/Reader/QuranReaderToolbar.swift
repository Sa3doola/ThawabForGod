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
