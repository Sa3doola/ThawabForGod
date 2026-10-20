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
        /// Position in the curated list (what `DailyAyahRule.entryIndex` returns), not a date: the
        /// widget picks the day's entry itself, so a snapshot never goes stale.
        var index: Int
        var first: VerseReference
        var lastVerse: Int
        var surahNameArabic: String
        var surahNameEnglish: String
        var texts: [String]
        var translation: Translation?
    }

    var continueReading: ContinueReading?
    /// The whole curated list. An entry that could not be resolved is absent, never shifted.
    var entries: [DailyAyah] = []
    /// How many entries the curated list has, including any left out of `entries`.
    var listCount = 0
    /// The `sha256` of the curated list `entries` was built from.
    var listID: String?
    /// What `entries` was built from (list, app version, translation pack): when it changes the text
    /// may have, so the entries are rebuilt. Compared against this rather than against what resolved,
    /// so an entry that cannot resolve does not force a rebuild on every foreground.
    var entriesKey: String?
    /// App version the font was last copied for.
    var fontVersion: String?

    /// That day's entry, or nil when the list has none for it. Never another day's ayah.
    func dailyAyah(for date: Date, calendar: Calendar = DailyAyahRule.calendar) -> DailyAyah? {
        guard listCount > 0 else { return nil }
        let index = DailyAyahRule.entryIndex(for: date, count: listCount, calendar: calendar)
        return entries.first { $0.index == index }
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
    /// The fallback face for the ranges Hafs lacks (`QuranAyahText` names it).
    static let amiriFileName = "AmiriQuran-Regular.ttf"
    static let amiriPostScriptName = "AmiriQuran-Regular"

    /// `<group container>/Fonts`; nil without the App Group entitlement.
    static var containerFolderURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedDefaults.groupIdentifier)?
            .appendingPathComponent("Fonts", isDirectory: true)
    }

    /// `<group container>/Fonts/<fileName>`; nil without the App Group entitlement.
    static var containerFileURL: URL? {
        containerFolderURL?.appendingPathComponent(fileName)
    }
}
