//
//  QuranUserDataRecords.swift
//  ThawabForGod
//

import Foundation
import SwiftData

// SwiftData rows for the reader's marks. They stay inside Data: an instance is bound to the
// context that fetched it, so the domain values in QuranUserData.swift are what travel.
//
// Identity is `(surah, verse)` as two integers. Uniqueness is the repository's job (`#Unique`
// over several properties is iOS 18). Every property has a default so SwiftData can add these
// tables to an existing store by lightweight migration. The names deliberately differ from the
// deleted `QuranBookmarkRecord` / `ReadingPositionRecord`, so inference cannot map a new entity
// onto a stale table.

@Model
nonisolated final class AyahBookmarkRecord {
    var surah: Int = 0
    var verse: Int = 0
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(surah: Int, verse: Int, createdAt: Date, updatedAt: Date) {
        self.surah = surah
        self.verse = verse
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
nonisolated final class AyahNoteRecord {
    var surah: Int = 0
    var verse: Int = 0
    var text: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(surah: Int, verse: Int, text: String, createdAt: Date, updatedAt: Date) {
        self.surah = surah
        self.verse = verse
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
nonisolated final class AyahHighlightRecord {
    var surah: Int = 0
    var verse: Int = 0
    /// `HighlightColor.rawValue`: the raw values are a contract, and no `Color` is ever stored.
    var colorRaw: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(surah: Int, verse: Int, colorRaw: String, createdAt: Date, updatedAt: Date) {
        self.surah = surah
        self.verse = verse
        self.colorRaw = colorRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
nonisolated final class QuranReadingPositionRecord {
    var surah: Int = 0
    var verse: Int = 0
    var updatedAt: Date = Date.distantPast

    init(surah: Int, verse: Int, updatedAt: Date) {
        self.surah = surah
        self.verse = verse
        self.updatedAt = updatedAt
    }
}
