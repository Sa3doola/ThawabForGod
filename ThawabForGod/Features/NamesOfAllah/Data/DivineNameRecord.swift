//
//  DivineNameRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `divine_name` table, as SQLite stores it.
///
/// The same shape and the same reasoning as `DhikrRecord` and `TasbihPresetRecord` —
/// `init(row:)` written out rather than derived through `Decodable`, so the snake_case-to-camelCase
/// mapping is visible instead of hidden behind a column decoding strategy.
nonisolated struct DivineNameRecord: FetchableRecord, Sendable, Equatable {
    let id: Int
    let arabic: String
    let transliteration: String
    let meaningEnglish: String
    let explanationEnglish: String?
    let reference: String?

    init(row: Row) {
        id = row["id"]
        arabic = row["arabic"]
        transliteration = row["transliteration"]
        meaningEnglish = row["meaning_en"]
        explanationEnglish = row["explanation_en"]
        reference = row["reference"]
    }

    /// Memberwise, for the mapper's tests — they have a name to assert about and no database to
    /// fetch a row from.
    init(
        id: Int,
        arabic: String,
        transliteration: String,
        meaningEnglish: String,
        explanationEnglish: String?,
        reference: String?
    ) {
        self.id = id
        self.arabic = arabic
        self.transliteration = transliteration
        self.meaningEnglish = meaningEnglish
        self.explanationEnglish = explanationEnglish
        self.reference = reference
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension DivineNameRecord {

    /// Resolves the row down to the one language the reader asked for.
    ///
    /// An Arabic reader gets `nil` for the transliteration and the meaning rather than the
    /// English shown under an Arabic heading: the corpus has no Arabic glosses, and the detail
    /// screen omits the sections rather than mixing scripts. That is a real gap in the data, not
    /// a design flourish — see `Resources/Corpus/README.md`.
    ///
    /// The reference is language-independent: `(1:3) (17:110)` means the same thing either way.
    func domainValue(in language: AppLanguage) -> DivineName {
        let isArabic = language == .arabic

        return DivineName(
            id: id,
            arabic: arabic,
            transliteration: isArabic ? nil : transliteration,
            meaning: isArabic ? nil : meaningEnglish,
            explanation: isArabic ? nil : explanationEnglish,
            reference: reference
        )
    }
}
