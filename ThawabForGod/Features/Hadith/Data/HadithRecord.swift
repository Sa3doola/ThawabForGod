//
//  HadithRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `hadith` table, as SQLite stores it.
///
/// `id` is *not* carried into the domain value, and `part` is. That inversion is the point of
/// `HadithID`: the rowid is this file's own numbering and shifts when the corpus is rebuilt,
/// while collection-number-part is how the narration is published. See `HadithID`.
nonisolated struct HadithRecord: FetchableRecord, Sendable, Equatable {
    let id: Int
    let collectionID: String
    let bookNumber: Int
    let number: Int
    let part: Int
    let numberLast: Int
    let text: String

    init(row: Row) {
        id = row["id"]
        collectionID = row["collection_id"]
        bookNumber = row["book_number"]
        number = row["number"]
        part = row["part"]
        numberLast = row["number_last"]
        text = row["text"]
    }

    /// Memberwise, for the mapper's tests.
    init(
        id: Int,
        collectionID: String,
        bookNumber: Int,
        number: Int,
        part: Int,
        numberLast: Int,
        text: String
    ) {
        self.id = id
        self.collectionID = collectionID
        self.bookNumber = bookNumber
        self.number = number
        self.part = part
        self.numberLast = numberLast
        self.text = text
    }
}

nonisolated extension HadithRecord {
    var domainValue: Hadith {
        Hadith(
            id: HadithID(collection: collectionID, number: number, part: part),
            bookNumber: bookNumber,
            reference: HadithReference(
                collection: collectionID,
                first: number,
                last: numberLast
            ),
            text: text
        )
    }
}
