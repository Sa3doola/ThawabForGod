//
//  HijriDateService.swift
//  ThawabForGod
//

import Foundation

/// Hijri dates from Foundation's Umm al-Qura calendar, and the events that fall on them.
///
/// On device, offline, no library and no API — the conversion table ships inside ICU. Umm
/// al-Qura is the civil calendar of Saudi Arabia and the one most Hijri dates in circulation
/// are quoted from, which makes it the right default even though it is a *calculated*
/// calendar; see `IslamicEvent` for what that does and does not license the app to claim.
///
/// Stateless once built, so a `struct` and `nonisolated`: no actor hop to ask what day it is.
nonisolated struct HijriDateService: HijriDateServicing {

    /// Umm al-Qura, in the user's time zone.
    ///
    /// The time zone is not decoration. A Hijri day begins at sunset, but the civil
    /// approximation everyone uses starts it at midnight *local* time — so the same instant is
    /// two different Hijri dates either side of a zone boundary, and reading components in UTC
    /// would put the user a day out for a third of every day.
    private let calendar: Calendar

    private let events: [IslamicEvent]

    /// - Parameters:
    ///   - timeZone: defaults to the device's, and tracks it if the user travels.
    ///   - events: the fixed-date table. Injected so tests can supply their own instead of
    ///     depending on what is currently in the bundle.
    init(
        timeZone: TimeZone = .autoupdatingCurrent,
        events: [IslamicEvent] = IslamicEventTable.bundled()
    ) {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.events = events
    }

    func hijriComponents(for date: Date) -> HijriDate {
        let components = calendar.dateComponents([.day, .month, .year], from: date)

        guard let day = components.day,
              let month = components.month.flatMap(HijriMonth.init(rawValue:)),
              let year = components.year else {
            // Not a case Foundation produces: `dateComponents(_:from:)` fills every requested
            // field for a concrete instant, and outside Umm al-Qura's tabulated range
            // (1300–1600 AH, roughly 1882–2174 CE) ICU clamps rather than returns nothing.
            // The guard exists so this stays a total function and no caller has to branch on
            // an outcome that cannot arrive; the value is a placeholder, not a real date.
            return HijriDate(day: 1, month: .muharram, year: 1)
        }

        return HijriDate(day: day, month: month, year: year)
    }

    func islamicEvents(on date: Date) -> [IslamicEvent] {
        let hijri = hijriComponents(for: date)
        return events.filter { $0.month == hijri.month && $0.day == hijri.day }
    }
}

/// Loads the bundled events table.
///
/// A plain JSON resource, not SwiftData: this is static reference data that ships with the
/// app and is never written to, and `Core/Persistence` is reserved for what the user changes.
nonisolated enum IslamicEventTable {
    static let resourceName = "IslamicEvents"

    /// Returns an empty table if the resource is missing or malformed, rather than trapping —
    /// a packaging mistake must not take the app down over a badge on the Home screen. What
    /// stops that failing silently is `IslamicEventTableTests`, which asserts the real bundle
    /// decodes to the expected events, so a broken table is a red test rather than a quiet
    /// absence nobody notices.
    static func bundled(_ bundle: Bundle = .main) -> [IslamicEvent] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([IslamicEvent].self, from: data) else {
            return []
        }

        return events
    }
}
