//
//  HomeGreeting.swift
//  ThawabForGod
//

import Foundation

/// How Home says hello, by the hour.
///
/// Three greetings rather than four. English could distinguish a late evening from a night, but
/// Arabic has two — صباح الخير until noon and مساء الخير after it — and a greeting that is more
/// finely graded in one language than the other is a translation asking to be fudged. So the
/// boundaries are drawn where both languages agree, and `evening` covers the night as well: a
/// user awake at two in the morning is greeted for the evening they are still in, not wished good
/// night by an app they have just opened.
nonisolated enum HomeGreeting: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening

    var labelKey: L10nKey {
        switch self {
        case .morning: .greetingMorning
        case .afternoon: .greetingAfternoon
        case .evening: .greetingEvening
        }
    }

    /// - Parameter calendar: Gregorian in the device's zone. `Calendar.current` would answer in
    ///   Hijri hours on a device set to the Islamic calendar — the same trap `PrayerTimeEngine`
    ///   documents, and the hour is a civil one.
    static func at(_ date: Date, calendar: Calendar = .gregorianLocal) -> HomeGreeting {
        switch calendar.component(.hour, from: date) {
        case 5..<12: .morning
        case 12..<17: .afternoon
        default: .evening
        }
    }
}
