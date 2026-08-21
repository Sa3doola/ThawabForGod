//
//  TafsirEditionRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `edition` table, as SQLite stores it.
///
/// The same shape and reasoning as `SurahRecord`: `init(row:)` written out so the
/// snake_case-to-camelCase mapping is visible rather than hidden behind a decoding strategy.
nonisolated struct TafsirEditionRecord: FetchableRecord, Sendable, Equatable {
    let id: String
    let arabicName: String
    let englishName: String
    let arabicAuthor: String
    let englishAuthor: String
    let language: String
    let licence: String

    init(row: Row) {
        id = row["id"]
        arabicName = row["name_ar"]
        englishName = row["name_en"]
        arabicAuthor = row["author_ar"]
        englishAuthor = row["author_en"]
        language = row["language"]
        licence = row["licence"]
    }

    /// Memberwise, for the mapper's tests.
    init(
        id: String,
        arabicName: String,
        englishName: String,
        arabicAuthor: String,
        englishAuthor: String,
        language: String,
        licence: String
    ) {
        self.id = id
        self.arabicName = arabicName
        self.englishName = englishName
        self.arabicAuthor = arabicAuthor
        self.englishAuthor = englishAuthor
        self.language = language
        self.licence = licence
    }

    /// `nil` for a language this build has no case for — which costs that edition its row rather
    /// than trapping the list, the same choice `SurahRecord` makes for a revelation place.
    var domainValue: TafsirEdition? {
        guard let language = AppLanguage(rawValue: language) else { return nil }

        return TafsirEdition(
            id: id,
            arabicName: arabicName,
            englishName: englishName,
            arabicAuthor: arabicAuthor,
            englishAuthor: englishAuthor,
            language: language,
            licence: licence
        )
    }
}
