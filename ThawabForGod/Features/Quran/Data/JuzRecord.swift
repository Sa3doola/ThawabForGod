//
//  JuzRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `juz` table, as SQLite stores it.
nonisolated struct JuzRecord: FetchableRecord, Sendable, Equatable {
    let number: Int
    let startSurah: Int
    let startVerse: Int
    let endSurah: Int
    let endVerse: Int

    init(row: Row) {
        number = row["number"]
        startSurah = row["start_surah"]
        startVerse = row["start_verse"]
        endSurah = row["end_surah"]
        endVerse = row["end_verse"]
    }

    /// Memberwise, for the mapper's tests.
    init(number: Int, startSurah: Int, startVerse: Int, endSurah: Int, endVerse: Int) {
        self.number = number
        self.startSurah = startSurah
        self.startVerse = startVerse
        self.endSurah = endSurah
        self.endVerse = endVerse
    }
}

nonisolated extension JuzRecord {
    var domainValue: Juz {
        Juz(
            id: number,
            start: VerseReference(surah: startSurah, verse: startVerse),
            end: VerseReference(surah: endSurah, verse: endVerse)
        )
    }
}
