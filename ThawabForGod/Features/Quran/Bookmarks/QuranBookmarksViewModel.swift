//
//  QuranBookmarksViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// The Bookmarks screen's session: which kind, which order, and the note being edited. They live
/// here rather than in the view so they survive an iPad crossing between compact and regular width.
/// Session-only: nothing is written to settings.
///
/// Reads only the selected kind's array of the store, so a change to another kind does not redraw
/// this screen. The list never waits for the corpus; names and excerpts appear when it arrives.
@MainActor
@Observable
final class QuranBookmarksViewModel {
    var kind: QuranMarkKind = .bookmarks
    var order: QuranMarkOrder = .date
    var editingNote: VerseReference?

    /// Handed to the note editor, which writes through it.
    @ObservationIgnored let userData: QuranUserDataStore
    @ObservationIgnored private let reader: QuranReaderViewModel

    init(userData: QuranUserDataStore, reader: QuranReaderViewModel) {
        self.userData = userData
        self.reader = reader
    }

    var isLoaded: Bool { userData.isLoaded }

    /// `nil` until the corpus has loaded (or if it failed); every use of it is optional.
    var corpus: QuranCorpus? { reader.corpus }

    var sections: [QuranMarkSection] {
        let rows: [QuranMarkRow]
        switch kind {
        case .bookmarks:
            rows = userData.bookmarks.map { QuranMarkRow(ayah: $0.ayah, date: $0.createdAt) }
        case .notes:
            rows = userData.notes.map { QuranMarkRow(ayah: $0.ayah, date: $0.updatedAt, note: $0.text) }
        case .highlights:
            rows = userData.highlights.map { QuranMarkRow(ayah: $0.ayah, date: $0.updatedAt, color: $0.color) }
        }
        return QuranMarkList.sections(rows, order: order)
    }

    func prepare() async {
        await reader.load()
    }

    /// Removes the user's mark of the selected kind; the ayah itself is untouched.
    func delete(_ row: QuranMarkRow) {
        switch kind {
        case .bookmarks: userData.setBookmarked(false, ayah: row.ayah)
        case .notes: userData.setNote("", for: row.ayah)
        case .highlights: userData.setHighlight(nil, for: row.ayah)
        }
    }
}
