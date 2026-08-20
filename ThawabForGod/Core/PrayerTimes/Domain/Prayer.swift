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

    /// The SF Symbol that stands for this marker on the day's timeline.
    ///
    /// A symbol name is a plain string, so naming it here costs Domain no import — the same
    /// trade `AppTab` makes. Symbols rather than bundled art because they carry Dynamic Type and
    /// the platform's own rendering modes without a second copy of each icon.
    var symbol: String {
        switch self {
        case .fajr: "sunrise"
        case .sunrise: "sun.horizon"
        case .dhuhr: "sun.max"
        case .asr: "sun.haze"
        case .maghrib: "sunset"
        case .isha: "moon.stars"
        }
    }

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
