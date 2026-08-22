//
//  PrayerTimeEngine.swift
//  ThawabForGod
//

import Adhan
import Foundation

/// Prayer times and the Qibla bearing, computed on device with Adhan.
///
/// **This is the only file in the app that imports Adhan.** Everything above it speaks in
/// domain entities, which is what keeps `Prayer` and `Coordinates` free of a third-party
/// dependency and lets the library be replaced without touching a view or a use case.
///
/// Stateless and `nonisolated`: a day of prayer times is pure arithmetic over a few solar
/// angles, so it runs wherever the caller already is — no actor hop, no `await`.
nonisolated struct PrayerTimeEngine: PrayerTimeCalculating {

    /// Always Gregorian, with the user's time zone.
    ///
    /// Both halves matter. Adhan wants the *Gregorian* year/month/day of the local civil day,
    /// so reading components through `Calendar.current` would hand it Hijri numbers on a
    /// device set to the Islamic calendar. And the time zone decides which day a given
    /// instant belongs to at all.
    private let calendar: Calendar

    /// - Parameter timeZone: defaults to the device's, and tracks it if the user travels.
    init(timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        // Adhan's initializer is failable, and it means it: near the poles there are days
        // with no sunrise or no sunset, and the twilight angles simply have no solution.
        guard let times = Adhan.PrayerTimes(
            coordinates: coordinates.adhanCoordinates,
            date: components,
            calculationParameters: config.adhanParameters
        ) else {
            throw PrayerTimeError.notComputable(date)
        }

        // A second pass over the same day's times, which is all Adhan needs for it.
        let sunnah = Adhan.SunnahTimes(from: times)

        return PrayerSchedule(
            day: calendar.startOfDay(for: date),
            times: [
                PrayerTime(prayer: .fajr, date: times.fajr),
                PrayerTime(prayer: .sunrise, date: times.sunrise),
                PrayerTime(prayer: .dhuhr, date: times.dhuhr),
                PrayerTime(prayer: .asr, date: times.asr),
                PrayerTime(prayer: .maghrib, date: times.maghrib),
                PrayerTime(prayer: .isha, date: times.isha)
            ],
            night: sunnah.map {
                NightTimes(
                    middleOfNight: $0.middleOfTheNight,
                    lastThirdOfNight: $0.lastThirdOfTheNight
                )
            }
        )
    }

    func qiblaBearing(from coordinates: Coordinates) -> Double {
        Adhan.Qibla(coordinates: coordinates.adhanCoordinates).direction
    }
}

// MARK: - Domain to Adhan

// Every mapping into the library lives here, so the translation is one short file rather than
// a habit that spreads. Adhan's `Coordinates` shares its name with the domain entity, hence
// the explicit `Adhan.` qualification throughout.

nonisolated private extension Coordinates {
    var adhanCoordinates: Adhan.Coordinates {
        Adhan.Coordinates(latitude: latitude, longitude: longitude)
    }
}

nonisolated private extension CalculationConfig {
    /// Adhan exposes its presets only through `CalculationMethod.params`, so the method is
    /// resolved first and the madhab layered on top.
    var adhanParameters: Adhan.CalculationParameters {
        var parameters = method.adhanMethod.params
        parameters.madhab = madhab.adhanMadhab
        return parameters
    }
}

nonisolated private extension PrayerCalculationMethod {
    var adhanMethod: Adhan.CalculationMethod {
        switch self {
        case .muslimWorldLeague: .muslimWorldLeague
        case .egyptian: .egyptian
        case .karachi: .karachi
        case .ummAlQura: .ummAlQura
        case .dubai: .dubai
        case .moonsightingCommittee: .moonsightingCommittee
        case .northAmerica: .northAmerica
        case .kuwait: .kuwait
        case .qatar: .qatar
        case .singapore: .singapore
        case .tehran: .tehran
        case .turkey: .turkey
        }
    }
}

nonisolated private extension AsrMadhab {
    var adhanMadhab: Adhan.Madhab {
        switch self {
        case .shafi: .shafi
        case .hanafi: .hanafi
        }
    }
}
