//
//  CalculationConfig.swift
//  ThawabForGod
//

import Foundation

/// How a day's times should be calculated. Two independent choices, both of which the user
/// picks during onboarding and can change later in Settings.
nonisolated struct CalculationConfig: Equatable, Sendable {
    /// Which authority's twilight angles to use for Fajr and Isha.
    var method: PrayerCalculationMethod

    /// Which school's shadow rule to use for Asr.
    var madhab: AsrMadhab

    init(method: PrayerCalculationMethod, madhab: AsrMadhab) {
        self.method = method
        self.madhab = madhab
    }

    /// The safe global starting point when nothing is known about the user yet.
    static let `default` = CalculationConfig(method: .muslimWorldLeague, madhab: .shafi)
}

/// The calculation authorities the app offers.
///
/// These mirror the presets the engine's library ships, minus its "custom angles" escape
/// hatch — the app has no UI for entering raw angles, so offering the case would be a lie.
nonisolated enum PrayerCalculationMethod: String, CaseIterable, Identifiable, Sendable {
    case muslimWorldLeague
    case egyptian
    case karachi
    case ummAlQura
    case dubai
    case moonsightingCommittee
    case northAmerica
    case kuwait
    case qatar
    case singapore
    case tehran
    case turkey

    var id: String { rawValue }
}

/// Which school of jurisprudence decides when Asr begins. Shafi (also Maliki, Hanbali and
/// Jafari) uses a shadow of one object-length; Hanafi uses two.
nonisolated enum AsrMadhab: String, CaseIterable, Identifiable, Sendable {
    case shafi
    case hanafi

    var id: String { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .shafi: .madhabShafi
        case .hanafi: .madhabHanafi
        }
    }
}
