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
}
