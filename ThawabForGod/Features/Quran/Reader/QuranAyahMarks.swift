//
//  QuranAyahMarks.swift
//  ThawabForGod
//

/// The reader's own marks on the ayahs — highlights, bookmarks and notes — as both readers draw them.
///
/// Lookups rather than a dictionary because the pages ask per ayah, synchronously, while they
/// draw: the reader's user data answers from an in-memory cache it keeps on the main actor. Call
/// them only at the top level of a leaf view's `body` (or build a snapshot there), so the store's
/// dictionaries are observed by that view.
struct QuranAyahMarks {
    let highlight: (VerseReference) -> HighlightColor?
    let isBookmarked: (VerseReference) -> Bool
    /// The note's text, for VoiceOver and the row's indicator.
    let noteText: (VerseReference) -> String?

    func hasNote(_ ayah: VerseReference) -> Bool { noteText(ayah) != nil }

    static let none = QuranAyahMarks(highlight: { _ in nil }, isBookmarked: { _ in false }, noteText: { _ in nil })

    /// The marks of `ayahs` as plain values, for passing below the view that observed them.
    func snapshot(of ayahs: some Sequence<VerseReference>) -> QuranAyahMarkSnapshot {
        var result = QuranAyahMarkSnapshot()
        for ayah in ayahs {
            if let color = highlight(ayah) { result.highlights[ayah] = color }
            if isBookmarked(ayah) { result.bookmarked.insert(ayah) }
            if let text = noteText(ayah) { result.notes[ayah] = text }
        }
        return result
    }
}

/// The marks on one page or row, as values: comparable, so a page whose marks did not change is
/// not redrawn, and free of closures, so nothing below it reads the store.
nonisolated struct QuranAyahMarkSnapshot: Equatable, Sendable {
    var highlights: [VerseReference: HighlightColor] = [:]
    var bookmarked: Set<VerseReference> = []
    var notes: [VerseReference: String] = [:]

    static let empty = QuranAyahMarkSnapshot()

    func highlight(_ ayah: VerseReference) -> HighlightColor? { highlights[ayah] }
    func isBookmarked(_ ayah: VerseReference) -> Bool { bookmarked.contains(ayah) }
    func note(_ ayah: VerseReference) -> String? { notes[ayah] }

    /// Some ayah in the snapshot is bookmarked: the page's ribbon.
    var hasBookmark: Bool { !bookmarked.isEmpty }
}
