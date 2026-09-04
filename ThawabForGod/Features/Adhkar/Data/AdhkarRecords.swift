//
//  AdhkarRecords.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `category` table, plus the count of adhkar under it that the query supplies.
///
/// It exists so the shape of the database and the shape of the app can change independently:
/// column names are snake_case and the domain's properties are not, and the domain has an
/// `AdhkarGroup` where SQLite has a string.
///
/// `init(row:)` is written out rather than derived through `Decodable`, for the reason the
/// hand-written mapping is the point of the type at all — a decoding strategy or a set of
/// `CodingKeys` would hide it.
nonisolated struct AdhkarCategoryRecord: FetchableRecord, Sendable, Equatable {
    let id: String
    let titleArabic: String
    let titleEnglish: String
    let groupID: String
    let sortOrder: Int
    let dhikrCount: Int

    init(row: Row) {
        id = row["id"]
        titleArabic = row["title_ar"]
        titleEnglish = row["title_en"]
        groupID = row["group_id"]
        sortOrder = row["sort_order"]
        dhikrCount = row["dhikr_count"]
    }

    /// Memberwise, for tests that have a value to assert about and no database to fetch a row from.
    init(
        id: String,
        titleArabic: String,
        titleEnglish: String,
        groupID: String,
        sortOrder: Int,
        dhikrCount: Int
    ) {
        self.id = id
        self.titleArabic = titleArabic
        self.titleEnglish = titleEnglish
        self.groupID = groupID
        self.sortOrder = sortOrder
        self.dhikrCount = dhikrCount
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension AdhkarCategoryRecord {

    /// `nil` where the corpus names a group this build has no case for.
    ///
    /// Dropped rather than trapped, and dropped rather than filed under some fallback heading: a
    /// chapter under the wrong heading is worse than a chapter the reader reaches through search,
    /// and this build's list of groups is the thing that would be out of date.
    var domainValue: AdhkarCategory? {
        guard let group = AdhkarGroup(rawValue: groupID) else { return nil }

        return AdhkarCategory(
            id: id,
            titleArabic: titleArabic,
            titleEnglish: titleEnglish,
            group: group,
            sortOrder: sortOrder,
            dhikrCount: dhikrCount
        )
    }
}

/// One row of the `dhikr` table.
nonisolated struct DhikrRecord: FetchableRecord, Sendable, Equatable {
    let id: Int
    let arabicText: String
    let repeatCount: Int

    init(row: Row) {
        id = row["id"]
        arabicText = row["arabic_text"]
        repeatCount = row["repeat_count"]
    }

    init(id: Int, arabicText: String, repeatCount: Int) {
        self.id = id
        self.arabicText = arabicText
        self.repeatCount = repeatCount
    }
}

nonisolated extension DhikrRecord {

    var domainValue: Dhikr {
        Dhikr(
            id: id,
            arabicText: arabicText,
            // Clamped, not trusted, even though the schema carries the same check. The corpus is
            // third-party content nobody has read line by line yet — see
            // `Resources/Corpus/README.md` — and a zero here is a counter that can never be
            // finished.
            repeatCount: max(1, repeatCount)
        )
    }
}
