//
//  PrayerCalculationMethod+Region.swift
//  ThawabForGod
//

import Foundation

nonisolated extension PrayerCalculationMethod {
    /// The method most likely to be right where the user is, used to preselect the onboarding
    /// picker. A starting point, never a decision — the user can change it there and again in
    /// Settings.
    ///
    /// Region comes from the locale rather than from GPS on purpose: it must work before
    /// location permission has been asked for, and offline.
    static func recommended(for locale: Locale = .autoupdatingCurrent) -> PrayerCalculationMethod {
        guard let region = locale.region?.identifier else {
            return .muslimWorldLeague
        }

        return switch region {
        case "SA": .ummAlQura
        case "AE": .dubai
        case "EG": .egyptian
        case "PK", "IN", "BD", "AF", "LK": .karachi
        case "KW": .kuwait
        case "QA": .qatar
        case "SG", "MY", "ID", "BN": .singapore
        case "IR": .tehran
        case "TR": .turkey
        case "US", "CA": .northAmerica
        case "GB", "IE": .moonsightingCommittee
        // Everywhere else, including most of Africa and mainland Europe, where the Muslim
        // World League angles are the common default.
        default: .muslimWorldLeague
        }
    }

    var labelKey: L10nKey {
        switch self {
        case .muslimWorldLeague: .methodMuslimWorldLeague
        case .egyptian: .methodEgyptian
        case .karachi: .methodKarachi
        case .ummAlQura: .methodUmmAlQura
        case .dubai: .methodDubai
        case .moonsightingCommittee: .methodMoonsightingCommittee
        case .northAmerica: .methodNorthAmerica
        case .kuwait: .methodKuwait
        case .qatar: .methodQatar
        case .singapore: .methodSingapore
        case .tehran: .methodTehran
        case .turkey: .methodTurkey
        }
    }
}
