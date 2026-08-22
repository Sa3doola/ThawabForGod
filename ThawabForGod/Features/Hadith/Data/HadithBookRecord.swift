//
//  HadithBookRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `book` table, as SQLite stores it.
nonisolated struct HadithBookRecord: FetchableRecord, Sendable, Equatable {
    let collectionID: String
    let number: Int
    let arabicTitle: String
    let englishTitle: String
    let hadithCount: Int

    init(row: Row) {
        collectionID = row["collection_id"]
        number = row["number"]
        arabicTitle = row["title_ar"]
        englishTitle = row["title_en"]
        hadithCount = row["hadith_count"]
    }

    /// Memberwise, for the mapper's tests.
    init(
        collectionID: String,
        number: Int,
        arabicTitle: String,
        englishTitle: String,
        hadithCount: Int
    ) {
        self.collectionID = collectionID
        self.number = number
        self.arabicTitle = arabicTitle
        self.englishTitle = englishTitle
        self.hadithCount = hadithCount
    }
}

nonisolated extension HadithBookRecord {
    var domainValue: HadithBook {
        HadithBook(
            collectionID: collectionID,
            number: number,
            arabicTitle: arabicTitle,
            englishTitle: englishTitle,
            hadithCount: hadithCount
        )
    }
}
