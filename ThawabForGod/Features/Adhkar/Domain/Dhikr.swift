//
//  Dhikr.swift
//  ThawabForGod
//

import Foundation

/// One remembrance, ready to read.
///
/// Already resolved to a single language by the time it gets here: `arabicText` is what everyone
/// sees, and `translation`, `transliteration`, `reference` and `virtue` are whichever of the
/// corpus's two languages the reader asked for. An Arabic reader gets `nil` for the first two —
/// not an empty string, and not the Arabic text repeated — because for them the text *is* the
/// dhikr, and there is nothing to translate it into.
///
/// A value type with no reference to the database it came from, so it crosses off the reader
/// queue to the main actor without a thought.
nonisolated struct Dhikr: Identifiable, Hashable, Sendable {

    /// Stable across languages and rebuilds — the same dhikr has the same id whether it was
    /// fetched for the morning or the evening. Safe to key a counter or a bookmark on.
    let id: Int

    /// The remembrance itself, vowelled, exactly as the corpus stores it. Always Arabic.
    let arabicText: String

    /// What it means, in the reader's language. `nil` when that language is Arabic.
    let translation: String?

    /// How to say it, for a reader who does not read the script. `nil` when the reader's
    /// language is Arabic, and `nil` where the corpus simply has none.
    let transliteration: String?

    /// Where it comes from, as the corpus writes it — `"Abu Dawood, No. 5074, and Ibn Majah,
    /// No. 3871. See: Sahih Ibn Majah, 2/332."`
    ///
    /// Deliberately one prose string rather than a parsed book-and-number pair. Most citations
    /// name several books, several numbers and a grading, so splitting them would throw away
    /// information and invent a precision the source does not have. It is shown verbatim, which
    /// is what lets a reader check the app rather than trust it.
    let reference: String

    /// The reward or benefit reported for it, where the corpus records one.
    let virtue: String?

    /// How many times it is to be said. Always at least one.
    let repeatCount: Int
}
