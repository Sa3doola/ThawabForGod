//
//  QuranUserData.swift
//  ThawabForGod
//

import Foundation

// The reader's own data on the Quran: bookmarks, notes, highlights (one of each per ayah) and the
// single reading position. Values only; the SwiftData rows stay in Data/UserData.

nonisolated struct QuranBookmark: Hashable, Sendable {
    let ayah: VerseReference
    let createdAt: Date
}

/// A plain-text note on one ayah.
nonisolated struct QuranNote: Hashable, Sendable {
    let ayah: VerseReference
    let text: String
    let createdAt: Date
    let updatedAt: Date

    /// The text trimmed, or `nil` when nothing is left. The store and the repository share this
    /// one rule so that "empty removes the note" cannot be decided two ways.
    static func normalizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// One highlighted ayah. The colour is a `HighlightColor`; drawing resolves it through the palette.
nonisolated struct QuranHighlight: Hashable, Sendable {
    let ayah: VerseReference
    let color: HighlightColor
    let createdAt: Date
    let updatedAt: Date
}

/// Where the reader last was. The ayah only, never a page: a page number belongs to one corpus.
nonisolated struct QuranReadingPosition: Hashable, Sendable {
    let ayah: VerseReference
    let updatedAt: Date
}

/// Everything marked, one entry per ayah per kind, in no particular order.
nonisolated struct QuranUserMarks: Hashable, Sendable {
    var bookmarks: [QuranBookmark] = []
    var notes: [QuranNote] = []
    var highlights: [QuranHighlight] = []
}

/// Bookmarks, notes and highlights. `async` because the implementation is a `@ModelActor`.
nonisolated protocol QuranUserDataRepositoring: Sendable {
    /// One entry per ayah per kind, unordered.
    func marks() async throws -> QuranUserMarks
    func setBookmarked(_ isBookmarked: Bool, ayah: VerseReference, at date: Date) async throws
    /// Empty text (after trimming) removes the note.
    func setNote(_ text: String, ayah: VerseReference, at date: Date) async throws
    /// `nil` removes the highlight.
    func setHighlight(_ color: HighlightColor?, ayah: VerseReference, at date: Date) async throws
    func removeAllMarks() async throws
}

nonisolated protocol QuranReadingPositionRepositoring: Sendable {
    func readingPosition() async throws -> QuranReadingPosition?
    func recordReadingPosition(_ ayah: VerseReference, at date: Date) async throws
}
