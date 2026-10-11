//
//  QuranAyahMarks.swift
//  ThawabForGod
//

/// The reader's own marks on the ayahs — highlights and bookmarks — as both readers draw them.
///
/// Two lookups rather than a dictionary because the pages ask per ayah, synchronously, while they
/// draw: the reader's user data (M6) answers from an in-memory cache it keeps on the main actor.
/// Empty until then.
struct QuranAyahMarks {
    let highlight: (VerseReference) -> HighlightColor?
    let isBookmarked: (VerseReference) -> Bool
    let hasNote: (VerseReference) -> Bool

    static let none = QuranAyahMarks(highlight: { _ in nil }, isBookmarked: { _ in false }, hasNote: { _ in false })
}
