//
//  HadithCollectionRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `collection` table, plus the two counts the list screen wants with it.
///
/// The same shape and the same reasoning as `SurahRecord` — `init(row:)` written out rather than
/// derived through `Decodable`, so the snake_case-to-camelCase mapping is visible instead of
/// hidden behind a column decoding strategy.
///
/// `bookCount` and `hadithCount` are not columns: they are counted by the query that fetches
/// this, which is why the record reads them off the row like everything else. Storing them in
/// the corpus would mean two places that have to agree about how many narrations there are.
nonisolated struct HadithCollectionRecord: FetchableRecord, Sendable, Equatable {
    let id: String
    let arabicName: String
    let englishName: String
    let arabicAuthor: String
    let englishAuthor: String
    let bookCount: Int
    let hadithCount: Int

    init(row: Row) {
        id = row["id"]
        arabicName = row["name_ar"]
        englishName = row["name_en"]
        arabicAuthor = row["author_ar"]
        englishAuthor = row["author_en"]
        bookCount = row["book_count"]
        hadithCount = row["hadith_count"]
    }

    /// Memberwise, for the mapper's tests — they have a row to assert about and no database to
    /// fetch one from.
    init(
        id: String,
        arabicName: String,
        englishName: String,
        arabicAuthor: String,
        englishAuthor: String,
        bookCount: Int,
        hadithCount: Int
    ) {
        self.id = id
        self.arabicName = arabicName
        self.englishName = englishName
        self.arabicAuthor = arabicAuthor
        self.englishAuthor = englishAuthor
        self.bookCount = bookCount
        self.hadithCount = hadithCount
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension HadithCollectionRecord {

    /// Total, unlike `SurahRecord`'s: every column here is text or a count, so there is no
    /// stored value this build could fail to make sense of.
    var domainValue: HadithCollection {
        HadithCollection(
            id: id,
            arabicName: arabicName,
            englishName: englishName,
            arabicAuthor: arabicAuthor,
            englishAuthor: englishAuthor,
            bookCount: bookCount,
            hadithCount: hadithCount
        )
    }
}
