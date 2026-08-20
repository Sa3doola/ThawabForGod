//
//  ReadingPositionRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `ReadingPosition` — the one row that says where the reader
/// left off.
///
/// `key` exists solely to be that "one row": a constant string with a uniqueness constraint on
/// it, so a write can find the existing row and replace it rather than appending. Without it,
/// every save would add a row and the store would grow with the reading. It is not derived from
/// anything and never varies — see `singletonKey`.
///
/// A single-row table is a slightly awkward thing to store, and the alternative was two keys in
/// `SettingsStore`. That store is for preferences the user *chose*, and a position is a side
/// effect of scrolling — see `ReadingPosition` for the whole argument.
@Model
nonisolated final class ReadingPositionRecord {

    /// The only value `key` ever takes. Named rather than written inline so the constraint and
    /// the lookup cannot drift apart.
    static let singletonKey = "current"

    @Attribute(.unique) var key: String = ReadingPositionRecord.singletonKey
    var surah: Int = 0
    var verse: Int = 0
    var updatedAt: Date = Date()

    init(surah: Int, verse: Int, updatedAt: Date) {
        self.key = Self.singletonKey
        self.surah = surah
        self.verse = verse
        self.updatedAt = updatedAt
    }

    var domainValue: ReadingPosition {
        ReadingPosition(
            reference: VerseReference(surah: surah, verse: verse),
            updatedAt: updatedAt
        )
    }

    func apply(_ position: ReadingPosition) {
        surah = position.reference.surah
        verse = position.reference.verse
        updatedAt = position.updatedAt
    }
}
