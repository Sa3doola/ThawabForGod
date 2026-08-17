//
//  DhikrRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `dhikr` table, as SQLite stores it: both languages side by side, column names
/// spelled the way the schema spells them.
///
/// It exists so the shape of the database and the shape of the app can change independently.
/// `Dhikr` is what the reading screen wants — one language, nothing optional that isn't
/// genuinely absent — and `domainValue(in:)` below is the one place that turns the first into
/// the second.
///
/// `init(row:)` is written out rather than derived through `Decodable`. The columns are
/// snake_case and the properties are not, so the derived version would need either a column
/// decoding strategy or a full set of `CodingKeys` — both of which hide the mapping that is the
/// entire point of this type.
nonisolated struct DhikrRecord: FetchableRecord, Sendable, Equatable {
    let id: Int
    let arabicText: String
    let translationEnglish: String
    let transliterationEnglish: String?
    let referenceArabic: String
    let referenceEnglish: String
    let virtueArabic: String?
    let virtueEnglish: String?
    let repeatCount: Int

    init(row: Row) {
        id = row["id"]
        arabicText = row["arabic_text"]
        translationEnglish = row["translation_en"]
        transliterationEnglish = row["transliteration_en"]
        referenceArabic = row["reference_ar"]
        referenceEnglish = row["reference_en"]
        virtueArabic = row["virtue_ar"]
        virtueEnglish = row["virtue_en"]
        repeatCount = row["repeat_count"]
    }

    /// Memberwise, for the mapper's tests — they have a `Dhikr` to assert about and no database
    /// to fetch a row from.
    init(
        id: Int,
        arabicText: String,
        translationEnglish: String,
        transliterationEnglish: String?,
        referenceArabic: String,
        referenceEnglish: String,
        virtueArabic: String?,
        virtueEnglish: String?,
        repeatCount: Int
    ) {
        self.id = id
        self.arabicText = arabicText
        self.translationEnglish = translationEnglish
        self.transliterationEnglish = transliterationEnglish
        self.referenceArabic = referenceArabic
        self.referenceEnglish = referenceEnglish
        self.virtueArabic = virtueArabic
        self.virtueEnglish = virtueEnglish
        self.repeatCount = repeatCount
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension DhikrRecord {

    /// Resolves the row down to the one language the reader asked for.
    ///
    /// An Arabic reader gets `nil` translation and `nil` transliteration rather than the Arabic
    /// text repeated back: the text *is* the dhikr for them, and the reading view uses those
    /// `nil`s to decide there is no translation toggle to offer.
    ///
    /// Any language other than Arabic resolves to the English columns, because English is what
    /// the corpus stores. A third language would need columns of its own before it needed a
    /// branch here.
    func domainValue(in language: AppLanguage) -> Dhikr {
        let isArabic = language == .arabic

        return Dhikr(
            id: id,
            arabicText: arabicText,
            translation: isArabic ? nil : translationEnglish,
            transliteration: isArabic ? nil : transliterationEnglish,
            reference: isArabic ? referenceArabic : referenceEnglish,
            virtue: isArabic ? virtueArabic : virtueEnglish,
            // Clamped, not trusted. A zero in the data would give the reader a counter that can
            // never be completed, and the corpus is third-party content that no one has verified
            // line by line yet — see `Resources/Corpus/README.md`.
            repeatCount: max(1, repeatCount)
        )
    }
}
