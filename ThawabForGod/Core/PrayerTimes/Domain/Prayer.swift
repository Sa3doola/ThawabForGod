//
//  Prayer.swift
//  ThawabForGod
//

import Foundation

/// The six markers that make up a day's timeline.
///
/// Sunrise is not a prayer — it marks the end of Fajr's window — but it sits on the same
/// timeline and users expect to see it, so it travels with the others. Anywhere only the
/// obligatory prayers make sense (reminders, for example), filter on `isObligatory`.
///
/// Declaration order is chronological, which is what makes `allCases` usable as a day's order.
nonisolated enum Prayer: String, CaseIterable, Identifiable, Sendable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var isObligatory: Bool { self != .sunrise }

    var labelKey: L10nKey {
        switch self {
        case .fajr: .prayerFajr
        case .sunrise: .prayerSunrise
        case .dhuhr: .prayerDhuhr
        case .asr: .prayerAsr
        case .maghrib: .prayerMaghrib
        case .isha: .prayerIsha
        }
    }
}
