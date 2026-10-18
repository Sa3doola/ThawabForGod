//
//  QuranWidgetSnapshot.swift
//  ThawabForGod
//

import Foundation

/// What the app tells the two Quran widgets, written to the App Group through `SettingsStore`.
///
/// The widget has no corpus (T5), so everything it draws is here: the reading position and the
/// next days' ayah of the day, with the Arabic text **stored exactly as `Ayah.text` reads** — no
/// marker, no join, no fallback mapping. The widget draws the markers itself.
///
/// Ported from Mushaf's `WidgetSnapshot`, with `AyahID` replaced by `VerseReference`.
nonisolated struct QuranWidgetSnapshot: Codable, Equatable, Sendable {

    struct ContinueReading: Codable, Equatable, Sendable {
        var ayah: VerseReference
        var surahNameArabic: String
        var surahNameEnglish: String
        /// Nil where the build has no printed page (Tanzil) or the reader is not on pages.
        var page: Int?
        var juz: Int?
    }

    struct Translation: Codable, Equatable, Sendable {
        var packID: String
        var nameArabic: String
        var nameEnglish: String
        var texts: [String]
        var isRightToLeft: Bool
    }

    struct DailyAyah: Codable, Equatable, Sendable {
        /// `DailyAyahRule.dayKey`, e.g. `2026-10-10`.
        var day: String
        var first: VerseReference
        var lastVerse: Int
        var surahNameArabic: String
        var surahNameEnglish: String
        var texts: [String]
        var translation: Translation?
    }

    var continueReading: ContinueReading?
    var days: [DailyAyah] = []
    /// The `sha256` of the curated list `days` was built from.
    var listID: String?
    /// App version the font was last copied for.
    var fontVersion: String?

    /// That day's entry, else the latest one before it, else the first.
    func dailyAyah(for date: Date, calendar: Calendar = DailyAyahRule.calendar) -> DailyAyah? {
        let key = DailyAyahRule.dayKey(for: date, calendar: calendar)
        if let exact = days.first(where: { $0.day == key }) { return exact }
        // Keys are zero-padded ISO dates, so string order is date order.
        if let earlier = days.filter({ $0.day < key }).max(by: { $0.day < $1.day }) { return earlier }
        return days.first
    }

    static func load(from store: any SettingsStore) -> QuranWidgetSnapshot? {
        guard let json = store.string(for: .quranWidgetSnapshot),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QuranWidgetSnapshot.self, from: data)
    }

    func save(to store: any SettingsStore) {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else { return }
        store.set(json, for: .quranWidgetSnapshot)
    }
}

/// The `kind` strings of the two Quran widgets. Fixed: an installed widget is bound to its kind.
nonisolated enum QuranWidgetKind {
    static let continueReading = "QuranContinueReadingWidget"
    static let ayahOfTheDay = "QuranAyahOfTheDayWidget"
}

/// The Hafs face the app copies into the App Group container for the extension to register.
nonisolated enum QuranWidgetFont {
    static let fileName = "KFGQPC-HafsUthmanic.ttf"
    static let postScriptName = "KFGQPCHAFSUthmanicScript-Regula"

    /// `<group container>/Fonts/<fileName>`; nil without the App Group entitlement.
    static var containerFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.groupIdentifier)?
            .appendingPathComponent("Fonts", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
