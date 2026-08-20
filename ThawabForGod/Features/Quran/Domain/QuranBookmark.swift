//
//  QuranBookmark.swift
//  ThawabForGod
//

import Foundation

/// A verse the reader has kept.
///
/// **The verse is the identity.** There is no `UUID` here, and that is the whole design: a
/// bookmark answers "is this verse kept?", so keying it on anything else would allow the same
/// verse to be saved twice and leave the reader with two identical rows and no way to tell them
/// apart. Toggling becomes idempotent for free.
///
/// Deliberately carries no note. A bookmark in a mushaf is a ribbon, not an annotation — and a
/// note would mean an editor, a keyboard over the text, and a second thing to sync later. If
/// notes are ever wanted they are their own slice, on top of this one rather than inside it.
nonisolated struct QuranBookmark: Identifiable, Hashable, Sendable {

    /// Which verse, which is also the row's key.
    let id: VerseReference

    /// When it was kept — what the list is ordered by, newest first, because the reason to open
    /// this list is usually the thing just saved.
    let createdAt: Date

    var reference: VerseReference { id }

    init(reference: VerseReference, createdAt: Date = Date()) {
        self.id = reference
        self.createdAt = createdAt
    }
}
