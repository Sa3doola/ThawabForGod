//
//  ReadingPosition.swift
//  ThawabForGod
//

import Foundation

/// Where the reader last was.
///
/// One of these exists at a time, which is what separates it from a `QuranBookmark`: a bookmark
/// is chosen and accumulates, a position is a side effect of reading and is overwritten. They are
/// stored apart for that reason rather than as a bookmark with a flag on it — a "current" flag on
/// a list means every write has to clear the flag on whatever held it before, and one row that is
/// simply replaced cannot get out of step with itself.
///
/// It is user *state*, not a preference, so it lives in SwiftData with the counts and the
/// bookmarks rather than in `SettingsStore` — nobody chose it, and `SettingsStore`'s rule is that
/// only a chosen value is ever written.
nonisolated struct ReadingPosition: Hashable, Sendable {

    /// The verse to resume at.
    let reference: VerseReference

    /// When the reader was last there. Shown nowhere yet; stored because "continue reading" is
    /// the kind of affordance that eventually wants to say how long ago.
    let updatedAt: Date

    init(reference: VerseReference, updatedAt: Date = Date()) {
        self.reference = reference
        self.updatedAt = updatedAt
    }
}
