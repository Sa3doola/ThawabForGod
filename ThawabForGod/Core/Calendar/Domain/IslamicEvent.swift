//
//  IslamicEvent.swift
//  ThawabForGod
//

import Foundation

/// A date in the Islamic year that falls on a fixed Hijri day and month.
///
/// **These are calculated dates, not sighted ones.** The Umm al-Qura calendar is an
/// astronomical table; the beginning of Ramadan, the two Eids and the Day of Arafah are
/// declared locally by moon sighting and routinely land a day either side of what any
/// calculation says. That is not an error to be fixed — it is the difference between a
/// calendar and an announcement. Events that people plan around therefore carry `noteKey`,
/// and the app must never present these as authoritative dates for fasting or Eid.
nonisolated struct IslamicEvent: Identifiable, Equatable, Sendable, Decodable {
    /// Stable across releases and translations — safe to persist or key a reminder on.
    let id: String

    /// The event's name as a key, resolved to Arabic or English at display time.
    let nameKey: L10nKey

    /// The caveat to show alongside it, where one is warranted. `nil` where the date is
    /// genuinely fixed by the calendar and nothing is being implied about sighting.
    let noteKey: L10nKey?

    let month: HijriMonth
    let day: Int
}
