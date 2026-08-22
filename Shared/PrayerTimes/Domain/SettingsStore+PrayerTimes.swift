//
//  SettingsStore+PrayerTimes.swift
//  ThawabForGod
//

import Foundation

/// Reading the prayer-time preferences back out of the store.
///
/// One decode, however many readers. Three parts of the app need these two pairs — onboarding
/// reads back what it seeded, the composition root reads them to build Home, and the reminder
/// scheduler reads them every time it refills its window — and before this file existed the
/// first of those owned the only copy, which the other two would have had to duplicate.
///
/// Both are all-or-nothing, and that is the contract: half a config is not a config, and half a
/// coordinate pair is a point in the Gulf of Guinea.
nonisolated extension SettingsStore {

    /// The stored calculation choices, or `nil` if the pair has never been written.
    var storedCalculationConfig: CalculationConfig? {
        guard let method = string(for: .calculationMethod).flatMap(PrayerCalculationMethod.init(rawValue:)),
              let madhab = string(for: .asrMadhab).flatMap(AsrMadhab.init(rawValue:)) else {
            return nil
        }

        return CalculationConfig(method: method, madhab: madhab)
    }

    /// The stored position, or `nil` if it has never been captured.
    ///
    /// Read through `double(for:)`, which distinguishes an unset key from a stored zero — 0 is a
    /// perfectly good latitude, and treating it as "missing" would strand anyone on the equator.
    var storedCoordinates: Coordinates? {
        guard let latitude = double(for: .latitude),
              let longitude = double(for: .longitude) else {
            return nil
        }

        return Coordinates(latitude: latitude, longitude: longitude)
    }

    /// The last position the app actually resolved, or `nil` if it never has.
    ///
    /// A cache rather than a preference, and separate from `storedCoordinates` for exactly that
    /// reason. Onboarding's pair is a *choice*: the user was asked where they are and answered.
    /// Overwriting it every time CoreLocation returns a fix would quietly convert that answer
    /// into a moving value they never consented to, and would leave nothing to fall back to when
    /// the cache is wrong. Two keys keep the two facts apart.
    var lastKnownCoordinates: Coordinates? {
        guard let latitude = double(for: .lastKnownLatitude),
              let longitude = double(for: .lastKnownLongitude) else {
            return nil
        }

        return Coordinates(latitude: latitude, longitude: longitude)
    }

    /// Records a fix the app has just resolved.
    ///
    /// One writer — `CoreLocationService`, the single chokepoint every live fix in the app comes
    /// through — so there is no call site anywhere that has to remember to do this.
    func recordLastKnown(_ coordinates: Coordinates) {
        set(coordinates.latitude, for: .lastKnownLatitude)
        set(coordinates.longitude, for: .lastKnownLongitude)
    }

    /// The best position a process that cannot ask CoreLocation has to work with: where the app
    /// last was, falling back to what onboarding captured.
    ///
    /// `nil` is an answer, and callers must treat it as one. A widget or a reminder with no
    /// position says so; it does **not** fall back to Makkah the way Home does. Home can afford
    /// the placeholder because the reader is looking at the screen and can see where it thinks
    /// they are — a notification firing at Makkah's Maghrib on a phone in London arrives with
    /// nobody watching, and a Home Screen widget is wrong all day.
    var bestKnownCoordinates: Coordinates? {
        lastKnownCoordinates ?? storedCoordinates
    }
}
