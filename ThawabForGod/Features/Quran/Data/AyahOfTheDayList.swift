//
//  AyahOfTheDayList.swift
//  ThawabForGod
//

import Foundation

/// The curated "Ayah of the day" list, `ayah-of-the-day.json`, built by `Tools/QuranBuilder` from
/// the reviewed `ayah-of-the-day.txt`: single ayahs and ranges inside one surah, each readable on
/// its own. `DailyAyahRule` picks the entry for a date.
///
/// Ported from Mushaf's `AyahOfTheDayList` with `AyahID` as `VerseReference`. The file carries
/// references only, never text.
nonisolated struct AyahOfTheDayList: Decodable, Sendable {
    struct Entry: Decodable, Equatable, Sendable {
        let surah: Int
        let from: Int
        let to: Int

        var first: VerseReference { VerseReference(surah: surah, verse: from) }
        var last: Int { max(from, to) }
        var verses: [VerseReference] { (from...last).map { VerseReference(surah: surah, verse: $0) } }
        /// "2:255" or "94:5-6", as in the source file.
        var reference: String { from == to ? "\(surah):\(from)" : "\(surah):\(from)-\(to)" }
    }

    /// The source file's SHA-256: changes whenever the list is edited.
    let sha256: String
    /// The review status written at the top of the source.
    let status: String
    let entries: [Entry]

    func entry(for date: Date, calendar: Calendar = DailyAyahRule.calendar) -> Entry? {
        entries.isEmpty ? nil : entries[DailyAyahRule.entryIndex(for: date, count: entries.count, calendar: calendar)]
    }

    /// Reads the bundled list off the main actor; `nil` if the file is missing or malformed.
    @concurrent static func bundled(_ bundle: Bundle = .main) async -> AyahOfTheDayList? {
        guard let url = bundle.url(forResource: "ayah-of-the-day", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(AyahOfTheDayList.self, from: data)
    }
}
