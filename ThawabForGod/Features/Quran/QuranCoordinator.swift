//
//  QuranCoordinator.swift
//  ThawabForGod
//

import Observation

/// The screens the Quran tab can push. See docs/quran-migration/design/M5.1.md for the cases
/// later tasks add.
nonisolated enum QuranRoute: Hashable, Sendable {
    /// The reader. No payload: where it is lives on `QuranReaderViewModel`.
    case reader
    /// A surah's introduction, pushed from a Library row. Offered only where a surah-info pack
    /// exists in the interface language.
    case surahInfo(Int)
    /// Search. No payload: the text, scope and results live on `QuranSearchViewModel`.
    case search
    /// The bookmarks, notes and highlights list. No payload: kind and sort live on its view model.
    case bookmarks
}

/// Where the Quran tab is, kept outside the view tree like every other section's.
///
/// **At most one reader is ever on the path, and when there is one it is `path[0]`.** Two readers
/// would be two screens over one view model. So `open(_:)` never deepens the stack: from the root
/// it pushes, with the reader already showing it retargets in place, and from anything else it
/// replaces the stack with the reader. Surah info may sit above the reader or alone above the root,
/// and the reader is still `path[0]` when present.
///
/// **The place is applied before the path changes.** The coordinator holds the reader's view model
/// and hands it the target itself, so the reader's first frame is already at the new place. Had the
/// target waited on the coordinator for the reader to collect, the reader would first be built at
/// its previous place, flash it, and in separated mode could finish a stale scroll after the new one.
///
/// **The route carries no target**, because the reader's place changes with every page turn and a
/// payload would be stale a second after the push; the first time the view tree was rebuilt (an
/// iPad crossing compact and regular) the reader would be built from the route and jump back to
/// where it was opened. The place lives on the view model, outside the tree.
@Observable
@MainActor
final class QuranCoordinator {
    var path: [QuranRoute] = []

    /// Not state of the coordinator: nothing should observe it for the reader's sake.
    @ObservationIgnored private let reader: QuranReaderViewModel

    @ObservationIgnored private let search: QuranSearchViewModel

    /// The stored reading position. `nil` in tests and previews.
    @ObservationIgnored private let userData: QuranUserDataStore?

    init(reader: QuranReaderViewModel, search: QuranSearchViewModel, userData: QuranUserDataStore? = nil) {
        self.reader = reader
        self.search = search
        self.userData = userData
    }

    /// The reader has been pushed at least once in this process, so there is a place to go back to.
    /// A session flag; a stored position (`userData.hasReadingPosition`) covers a relaunch.
    private(set) var hasShownReader = false

    /// The reader is the screen at the top of this section's stack.
    var isReaderOnTop: Bool { path.last == .reader }

    /// Continue reading can be offered: there is a place, and the reader is not already on the stack.
    var canContinueReading: Bool {
        (hasShownReader || userData?.hasReadingPosition == true) && !path.contains(.reader)
    }

    /// Pushes a surah's introduction, unless it is already the screen in front.
    func showSurahInfo(_ surah: Int) {
        if path.last != .surahInfo(surah) { path.append(.surahInfo(surah)) }
    }

    /// Pushes Search, unless it is already the screen in front. A prefill replaces the text and
    /// resets the scope to the Arabic text. The reader, if on the stack, stays `path[0]`.
    func showSearch(prefill: String? = nil) {
        closePanel()
        if let prefill { search.prefill(prefill) }
        if path.last != .search { path.append(.search) }
    }

    /// Pushes the bookmarks list, unless it is already the screen in front.
    func showBookmarks() {
        closePanel()
        if path.last != .bookmarks { path.append(.bookmarks) }
    }

    // MARK: Ayah panel

    /// The ayah the panel is about. Kept after the panel closes, so there is no blank frame while
    /// the sheet animates out. Read only by `AyahPanel`.
    private(set) var panelAyah: VerseReference?
    var isPanelSheetPresented = false
    var isPanelInspectorPresented = false
    /// "Read more": the full tafsir, a sheet over the panel.
    var isTafsirReaderPresented = false
    /// The ayah whose note is being edited: a sheet the panel's content presents. Session state.
    var noteEditorAyah: VerseReference?

    /// Opens the note editor on `ayah`.
    func editNote(_ ayah: VerseReference) {
        noteEditorAyah = ayah
    }

    /// Whether the reader is wide enough for the inspector. Set by the presentation modifier from
    /// the measured reader; an open panel moves between sheet and inspector when it changes.
    var panelUsesInspector = false {
        didSet {
            guard panelUsesInspector != oldValue else { return }
            isTafsirReaderPresented = false
            noteEditorAyah = nil
            if panelUsesInspector,isPanelSheetPresented {
                isPanelSheetPresented = false
                isPanelInspectorPresented = true
            } else if !panelUsesInspector, isPanelInspectorPresented {
                isPanelInspectorPresented = false
                isPanelSheetPresented = true
            }
        }
    }

    /// The bottom panel is showing (tabletop: `QuranReadingSurface` reports it through `panelUsesBottom`).
    var isPanelBottomPresented = false

    /// Whether the panel should sit at the bottom. An open panel moves with it; the non-bottom
    /// target follows `panelUsesInspector` (the sheet wherever the inspector is unused).
    var panelUsesBottom = false {
        didSet {
            guard panelUsesBottom != oldValue else { return }
            isTafsirReaderPresented = false
            noteEditorAyah = nil
            if panelUsesBottom, isPanelSheetPresented || isPanelInspectorPresented {
                isPanelSheetPresented = false
                isPanelInspectorPresented = false
                isPanelBottomPresented = true
            } else if !panelUsesBottom, isPanelBottomPresented {
                isPanelBottomPresented = false
                if panelUsesInspector {
                    isPanelInspectorPresented = true
                } else {
                    isPanelSheetPresented = true
                }
            }
        }
    }

    /// The tabletop reader left the screen (a push over it, or Back): drop a bottom panel and the
    /// placement without re-presenting it as a sheet from a reader nobody is looking at.
    func endBottomPanel() {
        isPanelBottomPresented = false
        panelUsesBottom = false
    }

    /// A tap on an ayah: selects it and opens the panel on it.
    func showAyah(_ ayah: VerseReference) {
        reader.select(ayah)
        panelAyah = ayah
        // The settings sheet lets taps through to the page; two sheets cannot be up at once.
        isSettingsSheetPresented = false
        if panelUsesBottom {
            isPanelBottomPresented = true
        } else if panelUsesInspector {
            isPanelInspectorPresented = true
        } else {
            isPanelSheetPresented = true
        }
    }

    /// Some form of the ayah panel is showing.
    var isPanelOpen: Bool { isPanelSheetPresented || isPanelInspectorPresented || isPanelBottomPresented }

    /// ⌥⌘I: closes the panel if it is open, else opens it on `ayah`.
    func toggleAyahPanel(at ayah: VerseReference) {
        if isPanelOpen {
            closePanel()
        } else {
            showAyah(ayah)
        }
    }

    /// Bumped by `focusGoTo()`; the Library header focuses its field when it changes.
    private(set) var goToFocusRequest = 0

    /// ⌘G: returns to the Library and asks its go-to field to take focus.
    func focusGoTo() {
        popToRoot()
        goToFocusRequest += 1
    }

    /// Prev / next in the panel: the panel moves first, then the page or list follows it.
    func stepPanel(to ayah: VerseReference) {
        panelAyah = ayah
        reader.open(.ayah(ayah))
    }

    // MARK: Reader settings

    /// The reader's settings sheet. Session state, not a path case: it closes on relaunch.
    var isSettingsSheetPresented = false

    /// Opens the settings sheet. The panel closes first: an iPhone cannot show two sheets at once.
    func showSettings() {
        closePanel()
        isSettingsSheetPresented = true
    }

    func closePanel() {
        isPanelSheetPresented = false
        isPanelInspectorPresented = false
        isPanelBottomPresented = false
        isTafsirReaderPresented = false
        noteEditorAyah = nil
    }

    /// Applies `target` to the reader, then shows the reader. In that order.
    func open(_ target: GoToTarget) {
        closePanel()
        guard reader.open(target) else { return }
        showReader()
        // Before the corpus has loaded the target can only be parked, not checked, so the reader is
        // pushed on trust. If the load then finds the target names nothing (a stale stored reference
        // on a cold launch), the push is taken back rather than leaving the reader at the old place.
        if reader.corpus == nil {
            Task {
                await reader.load()
                if reader.takeRejectedParkedTarget() { path = [] }
            }
        }
    }

    /// Shows the reader where it was left: the live place if this process has one, else the stored
    /// reading position (opened without selecting the ayah).
    func openReader() {
        if !reader.hasLivePlace, let ayah = userData?.readingPosition?.ayah {
            open(.resume(ayah))
        } else {
            showReader()
        }
    }

    func popToRoot() {
        closePanel()
        path = []
    }

    private func showReader() {
        hasShownReader = true
        if path != [.reader] { path = [.reader] }
    }
}
