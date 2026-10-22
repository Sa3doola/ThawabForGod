//
//  QuranCommand.swift
//  ThawabForGod
//

import SwiftUI

/// Every Quran keyboard command, defined once. The Quran menu lists them with their main shortcut;
/// the reader's key glue binds the alternates to the same commands.
nonisolated enum QuranCommand: String, CaseIterable, Identifiable, Sendable {
    case nextPage, previousPage
    case nextSurah, previousSurah
    case goTo, search
    case bookmark, toggleAyahPanel
    case toggleDisplayMode, nextTheme
    case biggerText, smallerText

    var id: Self { self }

    /// The menu's groups, separated by dividers.
    static let groups: [[QuranCommand]] = [
        [.nextPage, .previousPage, .nextSurah, .previousSurah],
        [.goTo, .search],
        [.bookmark, .toggleAyahPanel],
        [.toggleDisplayMode, .nextTheme, .biggerText, .smallerText],
    ]

    var titleKey: L10nKey {
        switch self {
        case .nextPage: .quranCommandNextPage
        case .previousPage: .quranCommandPreviousPage
        case .nextSurah: .quranCommandNextSurah
        case .previousSurah: .quranCommandPreviousSurah
        case .goTo: .quranCommandGoTo
        case .search: .quranSearch
        case .bookmark: .quranCommandBookmark
        case .toggleAyahPanel: .quranCommandToggleAyahPanel
        case .toggleDisplayMode: .quranCommandToggleDisplayMode
        case .nextTheme: .quranCommandNextTheme
        case .biggerText: .quranCommandBiggerText
        case .smallerText: .quranCommandSmallerText
        }
    }

    var systemImage: String {
        switch self {
        case .nextPage: "chevron.left"
        case .previousPage: "chevron.right"
        case .goTo: "books.vertical"
        case .search: "magnifyingglass"
        case .bookmark: "bookmark"
        case .toggleAyahPanel: "sidebar.trailing"
        case .toggleDisplayMode: "book"
        case .nextTheme: "paintpalette"
        case .previousSurah: "chevron.forward.2"
        case .nextSurah: "chevron.backward.2"
        case .biggerText: "textformat.size.larger"
        case .smallerText: "textformat.size.smaller"
        }
    }

    /// The shortcut shown in the menu. A Mushaf is an Arabic book: the next page lies to the
    /// left, so ← turns forward and → back, in both languages.
    var shortcut: KeyboardShortcut {
        switch self {
        case .nextPage: KeyboardShortcut(.leftArrow, modifiers: [], localization: .withoutMirroring)
        case .previousPage: KeyboardShortcut(.rightArrow, modifiers: [], localization: .withoutMirroring)
        case .goTo: KeyboardShortcut("g", modifiers: .command)
        case .search: KeyboardShortcut("f", modifiers: .command)
        case .bookmark: KeyboardShortcut("d", modifiers: .command)
        case .toggleAyahPanel: KeyboardShortcut("i", modifiers: [.command, .option])
        case .toggleDisplayMode: KeyboardShortcut("t", modifiers: .command)
        case .nextTheme: KeyboardShortcut("t", modifiers: [.command, .shift])
        case .previousSurah: KeyboardShortcut("[", modifiers: .command)
        case .nextSurah: KeyboardShortcut("]", modifiers: .command)
        case .biggerText: KeyboardShortcut("+", modifiers: .command)
        case .smallerText: KeyboardShortcut("-", modifiers: .command)
        }
    }

    /// More keys for the same command, bound in the reader and not listed in the menu.
    var alternates: [KeyboardShortcut] {
        switch self {
        case .nextPage: [KeyboardShortcut(.space, modifiers: []), KeyboardShortcut(.pageDown, modifiers: [])]
        case .previousPage: [KeyboardShortcut(.space, modifiers: .shift), KeyboardShortcut(.pageUp, modifiers: [])]
        // ⌘= is ⌘+ without Shift on most layouts.
        case .biggerText: [KeyboardShortcut("=", modifiers: .command)]
        default: []
        }
    }
}

/// What a command does right now. Built by `AppContainer.quranCommandTarget`; it checks that the
/// Quran is the selected section, so the menu and the keys act on the Quran only while it is showing.
@MainActor
struct QuranCommandTarget {
    let coordinator: QuranCoordinator
    let reader: QuranReaderViewModel
    let userData: QuranUserDataStore
    /// Live check that the Quran is the selected section. A `TabView` keeps other tabs' views
    /// mounted, so focus alone does not say it.
    let isSectionActive: () -> Bool

    private var settings: QuranReaderSettings { reader.settings }

    /// Cheap reads only. Never `reader.location` or `mushaf.page`, which track the page, so the
    /// menu is not re-validated on every page turn.
    func isEnabled(_ command: QuranCommand) -> Bool {
        guard isSectionActive(),
              !coordinator.isSettingsSheetPresented,
              coordinator.noteEditorAyah == nil,
              !coordinator.isTafsirReaderPresented
        else { return false }
        switch command {
        case .search, .goTo:
            return true
        default:
            guard coordinator.isReaderOnTop, reader.corpus != nil else { return false }
        }
        switch command {
        case .toggleDisplayMode: return reader.canSwitchDisplayMode
        case .biggerText: return !reader.showsMushafPages && settings.canEnlargeText
        case .smallerText: return !reader.showsMushafPages && settings.canShrinkText
        default: return true
        }
    }

    func perform(_ command: QuranCommand) {
        guard isEnabled(command) else { return }
        // Search and Go to need no corpus.
        if command == .search || command == .goTo {
            performUnrestricted(command)
            return
        }
        guard let corpus = reader.corpus else { return }
        // Where the reader is looking, which moves as they read.
        let visible = reader.location
        // The ayah they tapped, if any. The selection is never cleared, so it can name an ayah that
        // scrolled away long ago: it is right for "this ayah" commands and wrong for "go on from
        // here" ones, which step from the visible place instead.
        let target = reader.mushaf.selectedAyah ?? visible
        switch command {
        case .nextPage: turn(.next, corpus: corpus, from: visible)
        case .previousPage: turn(.previous, corpus: corpus, from: visible)
        case .goTo, .search: performUnrestricted(command)
        case .bookmark: userData.toggleBookmark(target)
        case .toggleAyahPanel: coordinator.toggleAyahPanel(at: target)
        case .toggleDisplayMode: reader.toggleDisplayMode()
        case .nextTheme: cycleTheme()
        case .previousSurah: openSurah(visible.surah - 1)
        case .nextSurah: openSurah(visible.surah + 1)
        case .biggerText: settings.enlargeText()
        case .smallerText: settings.shrinkText()
        }
    }

    private func performUnrestricted(_ command: QuranCommand) {
        switch command {
        case .goTo: coordinator.focusGoTo()
        case .search: coordinator.showSearch()
        default: break
        }
    }

    private func turn(_ turn: MushafPageTurn, corpus: QuranCorpus, from current: VerseReference) {
        if reader.showsMushafPages {
            if reader.mushaf.canTurn(turn) { reader.mushaf.turn(turn) }
        } else {
            let next = turn == .next ? corpus.ayah(after: current) : corpus.ayah(before: current)
            if let next { reader.open(.ayah(next)) }
        }
    }

    private func openSurah(_ surah: Int) {
        guard (1...114).contains(surah) else { return }
        coordinator.open(.surah(surah))
    }

    /// Cycles the stored theme only; with "follow system" on in a dark system the page stays Dark
    /// whatever is picked, and the change shows in light mode.
    private func cycleTheme() {
        let all = ReaderTheme.allCases
        guard let index = all.firstIndex(of: settings.theme) else { return }
        settings.select(theme: all[(index + 1) % all.count])
    }
}
