//
//  Calendar+Local.swift
//  ThawabForGod
//

import Foundation

nonisolated extension Calendar {
    /// A Gregorian calendar in the device's own time zone.
    ///
    /// Not `Calendar.current`, and the difference is not cosmetic: a device set to the Islamic
    /// calendar answers `component(.day, from:)` in Hijri, so anything computing a *civil* day
    /// boundary from `current` silently gets a different one. `PrayerTimeEngine` builds this same
    /// calendar by hand for exactly that reason; this is that reasoning, named once.
    ///
    /// `autoupdatingCurrent` for the zone, so a device that crosses one follows it.
    static var gregorianLocal: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
