//
//  SurahRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `surah` table, as SQLite stores it.
///
/// The same shape and the same reasoning as `DhikrRecord` and `DivineNameRecord` — `init(row:)`
/// written out rather than derived through `Decodable`, so the snake_case-to-camelCase mapping
/// is visible instead of hidden behind a column decoding strategy.
nonisolated struct SurahRecord: FetchableRecord, Sendable, Equatable {
    let id: Int
    let arabicName: String
    let transliteration: String
    let englishName: String
    let verseCount: Int
    let revelationPlace: String
    let revelationOrder: Int
    let bismillah: String?

    init(row: Row) {
        id = row["id"]
        arabicName = row["name_ar"]
        transliteration = row["transliteration"]
        englishName = row["name_en"]
        verseCount = row["verse_count"]
        revelationPlace = row["revelation_place"]
        revelationOrder = row["revelation_order"]
        bismillah = row["bismillah"]
    }

    /// Memberwise, for the mapper's tests — they have a row to assert about and no database to
    /// fetch one from.
    init(
        id: Int,
        arabicName: String,
        transliteration: String,
        englishName: String,
        verseCount: Int,
        revelationPlace: String,
        revelationOrder: Int,
        bismillah: String?
    ) {
        self.id = id
        self.arabicName = arabicName
        self.transliteration = transliteration
        self.englishName = englishName
        self.verseCount = verseCount
        self.revelationPlace = revelationPlace
        self.revelationOrder = revelationOrder
        self.bismillah = bismillah
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension SurahRecord {

    /// `nil` when the stored revelation place is not one this build knows.
    ///
    /// A chapter is dropped rather than defaulted, for the reason `AdhkarRepository` drops an
    /// unknown category: guessing "Meccan" because the string did not parse would put a claim
    /// about revelation on screen that no source made.
    var domainValue: Surah? {
        guard let place = RevelationPlace(rawValue: revelationPlace) else { return nil }

        return Surah(
            id: id,
            arabicName: arabicName,
            transliteration: transliteration,
            englishName: englishName,
            verseCount: verseCount,
            revelationPlace: place,
            revelationOrder: revelationOrder,
            bismillah: bismillah
        )
    }
}
