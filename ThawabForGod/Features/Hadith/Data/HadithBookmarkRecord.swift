//
//  HadithBookmarkRecord.swift
//  ThawabForGod
//

import Foundation
import SwiftData

/// SwiftData's representation of a `HadithBookmark`. Stays inside `Data`, as every `@Model` in
/// this project does: an instance is bound to the context that fetched it and must never cross an
/// actor boundary — the domain value type is what travels.
///
/// The identity is stored as its three parts rather than as `"bukhari:402:1"`, so the store can
/// filter on them instead of parsing every row back. `HadithID` is rebuilt at the boundary, which
/// keeps the stringly-typed form out of the app entirely — the same choice `QuranBookmarkRecord`
/// makes with its two `Int`s.
///
/// **Uniqueness is the repository's job, not the schema's.** SwiftData's `@Attribute(.unique)` is
/// per-property, and what has to be unique here is the *triple* — `#Unique` over several
/// properties is iOS 18 and this app targets 17. So `HadithProgressRepository` fetches before it
/// inserts.
///
/// Every property carries a default, which SwiftData needs for lightweight migration to add this
/// model to a store that already exists — and every installed copy has one.
@Model
nonisolated final class HadithBookmarkRecord {
    var collection: String = ""
    var number: Int = 0
    var part: Int = 0
    var bookNumber: Int = 0
    var createdAt: Date = Date()

    init(collection: String, number: Int, part: Int, bookNumber: Int, createdAt: Date) {
        self.collection = collection
        self.number = number
        self.part = part
        self.bookNumber = bookNumber
        self.createdAt = createdAt
    }

    convenience init(_ bookmark: HadithBookmark) {
        self.init(
            collection: bookmark.id.collection,
            number: bookmark.id.number,
            part: bookmark.id.part,
            bookNumber: bookmark.bookNumber,
            createdAt: bookmark.createdAt
        )
    }

    var domainValue: HadithBookmark {
        HadithBookmark(
            id: HadithID(collection: collection, number: number, part: part),
            bookNumber: bookNumber,
            createdAt: createdAt
        )
    }
}

/// SwiftData's representation of a `HadithReadingPosition` — the single row that says which kitab
/// the reader was last in.
///
/// One row, enforced by the repository replacing rather than inserting. There is no id on it for
/// the same reason `ReadingPositionRecord` has none: what would it identify? A second row is a
/// bug, not a possibility the schema should make expressible.
@Model
nonisolated final class HadithReadingPositionRecord {
    var collection: String = ""
    var bookNumber: Int = 0
    var updatedAt: Date = Date()

    init(collection: String, bookNumber: Int, updatedAt: Date) {
        self.collection = collection
        self.bookNumber = bookNumber
        self.updatedAt = updatedAt
    }

    var domainValue: HadithReadingPosition {
        HadithReadingPosition(
            book: BookReference(collection: collection, number: bookNumber),
            updatedAt: updatedAt
        )
    }
}
