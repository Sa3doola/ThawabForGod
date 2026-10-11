//
//  QuranUserDataStore.swift
//  ThawabForGod
//

import Foundation
import Observation
import os

/// The reader's own marks on the Quran — bookmarks, notes, highlights — and where they left off,
/// held in memory on the main actor.
///
/// Pages ask per ayah, synchronously, while they draw, so the truth lives here in dictionaries and
/// the SwiftData store behind `QuranUserDataRepository` is the *backup*: loaded once at launch,
/// then written to in the order the reader acted. A write is applied to memory first (the tap shows
/// at once) and then appended to a serial chain, so writes reach the actor in tap order rather than
/// as unordered fire-and-forget tasks. A failed write is logged and answered by reloading from the
/// repository; there is no user-facing error.
@MainActor
@Observable
final class QuranUserDataStore {

    // MARK: Lists, newest first

    private(set) var bookmarks: [QuranBookmark] = []
    private(set) var notes: [QuranNote] = []
    private(set) var highlights: [QuranHighlight] = []
    private(set) var readingPosition: QuranReadingPosition?
    private(set) var isLoaded = false

    // MARK: Lookups

    private var bookmarkByAyah: [VerseReference: QuranBookmark] = [:]
    private var noteByAyah: [VerseReference: QuranNote] = [:]
    private var highlightByAyah: [VerseReference: QuranHighlight] = [:]

    // MARK: Plumbing

    @ObservationIgnored private let repository: any QuranUserDataRepositoring
    @ObservationIgnored private let positions: any QuranReadingPositionRepositoring
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var hasStartedLoading = false
    /// Links of the write chain not yet finished, and whether one of them failed.
    @ObservationIgnored private var linksInFlight = 0
    @ObservationIgnored private var needsReload = false
    /// Edits made before the load lands. The load read the disk before them, so they are applied
    /// again to memory once it assigns; each is idempotent and carries its own date.
    @ObservationIgnored private var pendingEdits: [() -> Void] = []
    @ObservationIgnored private static let logger = Logger(subsystem: "ThawabForGod", category: "QuranUserData")

    init(
        repository: any QuranUserDataRepositoring,
        positions: any QuranReadingPositionRepositoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.positions = positions
        self.now = now
    }

    // MARK: Loading

    /// Reads everything once. Idempotent; the head of the write chain, so no write overtakes it.
    func load() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        enqueue { [self] in
            // A load that fails must not leave the store waiting forever: it is marked loaded with
            // what the reader did meanwhile, and the next launch reads the disk again.
            do {
                let marks = try await repository.marks()
                let position = try await positions.readingPosition()
                replace(with: marks)
                readingPosition = position
            } catch {
                Self.logger.error("Load failed: \(String(describing: error), privacy: .public)")
            }
            let edits = pendingEdits
            pendingEdits = []
            isLoaded = true
            for edit in edits { edit() }
            rebuildLists()
        }
    }

    /// Awaits every write issued so far.
    func flush() async {
        await pending?.value
    }

    // MARK: Reading

    func isBookmarked(_ ayah: VerseReference) -> Bool { bookmarkByAyah[ayah] != nil }
    func note(for ayah: VerseReference) -> QuranNote? { noteByAyah[ayah] }
    func highlight(for ayah: VerseReference) -> HighlightColor? { highlightByAyah[ayah]?.color }

    /// What the pages draw from. The closures read the dictionaries, so a page that calls them
    /// while it draws is observing this store.
    var marks: QuranAyahMarks {
        QuranAyahMarks(
            highlight: { [self] in highlight(for: $0) },
            isBookmarked: { [self] in isBookmarked($0) },
            hasNote: { [self] in note(for: $0) != nil }
        )
    }

    // MARK: Writing

    func setBookmarked(_ isBookmarked: Bool, ayah: VerseReference) {
        let date = now()
        edit { $0.applyBookmark(isBookmarked, ayah: ayah, at: date) }
        enqueue { [repository] in try await repository.setBookmarked(isBookmarked, ayah: ayah, at: date) }
    }

    func toggleBookmark(_ ayah: VerseReference) {
        setBookmarked(!isBookmarked(ayah), ayah: ayah)
    }

    /// Empty after trimming removes the note.
    func setNote(_ text: String, for ayah: VerseReference) {
        let date = now()
        edit { $0.applyNote(text, ayah: ayah, at: date) }
        enqueue { [repository] in try await repository.setNote(text, ayah: ayah, at: date) }
    }

    func setHighlight(_ color: HighlightColor?, for ayah: VerseReference) {
        let date = now()
        edit { $0.applyHighlight(color, ayah: ayah, at: date) }
        enqueue { [repository] in try await repository.setHighlight(color, ayah: ayah, at: date) }
    }

    /// Written through on every call; M6.4 adds the debounce inside this method.
    func recordReadingPosition(_ ayah: VerseReference) {
        let date = now()
        // No list changes, so none is rebuilt: a page turn must not redraw the Library.
        edit(rebuildsLists: false) { $0.readingPosition = QuranReadingPosition(ayah: ayah, updatedAt: date) }
        enqueue { [positions] in try await positions.recordReadingPosition(ayah, at: date) }
    }

    #if DEBUG
    /// Forgets every mark, in memory and on disk, then reloads from the repository.
    func removeAllMarksForDebug() {
        pendingEdits = []
        replace(with: QuranUserMarks())
        enqueue { [repository] in try await repository.removeAllMarks() }
    }
    #endif

    // MARK: In-memory edits

    /// Applies a change now and, if the load has not landed, again after it.
    private func edit(rebuildsLists: Bool = true, _ change: @escaping (QuranUserDataStore) -> Void) {
        change(self)
        if !isLoaded { pendingEdits.append { [self] in change(self) } }
        if rebuildsLists { rebuildLists() }
    }

    private func applyBookmark(_ isBookmarked: Bool, ayah: VerseReference, at date: Date) {
        if isBookmarked {
            guard bookmarkByAyah[ayah] == nil else { return }
            bookmarkByAyah[ayah] = QuranBookmark(ayah: ayah, createdAt: date)
        } else {
            bookmarkByAyah[ayah] = nil
        }
    }

    private func applyNote(_ text: String, ayah: VerseReference, at date: Date) {
        guard let normalized = QuranNote.normalizedText(text) else {
            noteByAyah[ayah] = nil
            return
        }
        let existing = noteByAyah[ayah]
        guard existing?.text != normalized else { return }
        noteByAyah[ayah] = QuranNote(
            ayah: ayah,
            text: normalized,
            createdAt: existing?.createdAt ?? date,
            updatedAt: date
        )
    }

    private func applyHighlight(_ color: HighlightColor?, ayah: VerseReference, at date: Date) {
        guard let color else {
            highlightByAyah[ayah] = nil
            return
        }
        let existing = highlightByAyah[ayah]
        guard existing?.color != color else { return }
        highlightByAyah[ayah] = QuranHighlight(
            ayah: ayah,
            color: color,
            createdAt: existing?.createdAt ?? date,
            updatedAt: date
        )
    }

    private func replace(with marks: QuranUserMarks) {
        bookmarkByAyah = Dictionary(marks.bookmarks.map { ($0.ayah, $0) }, uniquingKeysWith: { first, _ in first })
        noteByAyah = Dictionary(marks.notes.map { ($0.ayah, $0) }, uniquingKeysWith: { first, _ in first })
        highlightByAyah = Dictionary(marks.highlights.map { ($0.ayah, $0) }, uniquingKeysWith: { first, _ in first })
        rebuildLists()
    }

    /// Assigns a list only if it differs, so a change to one kind (or to none) does not notify the
    /// views reading another.
    private func rebuildLists() {
        let newBookmarks = bookmarkByAyah.values.sorted { $0.createdAt > $1.createdAt }
        let newNotes = noteByAyah.values.sorted { $0.updatedAt > $1.updatedAt }
        let newHighlights = highlightByAyah.values.sorted { $0.updatedAt > $1.updatedAt }
        if newBookmarks != bookmarks { bookmarks = newBookmarks }
        if newNotes != notes { notes = newNotes }
        if newHighlights != highlights { highlights = newHighlights }
    }

    // MARK: The write chain

    /// Appends one link. A failure is logged and answered by reloading, so memory goes back to
    /// what is actually stored.
    private func enqueue(_ operation: @escaping @MainActor () async throws -> Void) {
        linksInFlight += 1
        pending = Task { [previous = pending] in
            await previous?.value
            do {
                try await operation()
            } catch {
                Self.logger.error("Write failed: \(String(describing: error), privacy: .public)")
                needsReload = true
            }
            linksInFlight -= 1
            // Only when the chain is idle: a reload in the middle would wipe the in-memory edits
            // of writes still queued behind this one, which then succeed on disk.
            if needsReload, linksInFlight == 0 {
                needsReload = false
                await reloadFromDisk()
            }
        }
    }

    private func reloadFromDisk() async {
        guard let marks = try? await repository.marks() else { return }
        replace(with: marks)
        if let position = try? await positions.readingPosition() { readingPosition = position }
    }
}
