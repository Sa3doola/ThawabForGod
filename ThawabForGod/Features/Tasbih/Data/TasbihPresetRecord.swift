//
//  TasbihPresetRecord.swift
//  ThawabForGod
//

import Foundation
import GRDB

/// One row of the `tasbih_preset` table, as SQLite stores it: both languages side by side,
/// column names spelled the way the schema spells them.
///
/// The same shape and the same reasoning as `DhikrRecord` — `init(row:)` written out rather than
/// derived through `Decodable`, so the snake_case-to-camelCase mapping is visible instead of
/// hidden behind a column decoding strategy.
nonisolated struct TasbihPresetRecord: FetchableRecord, Sendable, Equatable {
    let id: String
    let arabicText: String
    let translationEnglish: String
    let targetCount: Int

    init(row: Row) {
        id = row["id"]
        arabicText = row["arabic_text"]
        translationEnglish = row["translation_en"]
        targetCount = row["target_count"]
    }

    /// Memberwise, for the mapper's tests — they have a preset to assert about and no database
    /// to fetch a row from.
    init(id: String, arabicText: String, translationEnglish: String, targetCount: Int) {
        self.id = id
        self.arabicText = arabicText
        self.translationEnglish = translationEnglish
        self.targetCount = targetCount
    }
}

// Extensions inherit the module's `MainActor` default isolation, so this one opts out — the
// mapping is pure, and the repository calls it from a nonisolated context.
nonisolated extension TasbihPresetRecord {

    /// Resolves the row down to the one language the reader asked for.
    ///
    /// An Arabic reader gets `nil` rather than the phrase repeated back as its own translation,
    /// which is what lets the counter simply omit the line instead of printing it twice.
    func domainValue(in language: AppLanguage) -> TasbihDhikr {
        TasbihDhikr(
            id: id,
            arabicText: arabicText,
            translation: language == .arabic ? nil : translationEnglish,
            // Clamped as well as constrained in SQL. A target of zero would be a counter that can
            // never complete a lap, and defending against it here costs one call.
            targetCount: max(1, targetCount)
        )
    }
}
