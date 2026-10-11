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

    init(reader: QuranReaderViewModel) {
        self.reader = reader
    }

    /// The reader has been pushed at least once in this process, so there is a place to go back to.
    /// In memory: M6 replaces it with the restored `ReadingPosition`.
    private(set) var hasShownReader = false

    /// The reader is the screen at the top of this section's stack.
    var isReaderOnTop: Bool { path.last == .reader }

    /// Continue reading can be offered: there is a place, and the reader is not already on the stack.
    var canContinueReading: Bool { hasShownReader && !path.contains(.reader) }

    /// Pushes a surah's introduction, unless it is already the screen in front.
    func showSurahInfo(_ surah: Int) {
        if path.last != .surahInfo(surah) { path.append(.surahInfo(surah)) }
    }

    /// Applies `target` to the reader, then shows the reader. In that order.
    func open(_ target: GoToTarget) {
        reader.open(target)
        showReader()
    }

    /// Shows the reader where it was left.
    func openReader() {
        showReader()
    }

    func popToRoot() {
        path = []
    }

    private func showReader() {
        hasShownReader = true
        if path != [.reader] { path = [.reader] }
    }
}
