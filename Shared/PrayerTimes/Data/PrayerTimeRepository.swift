//
//  PrayerTimeRepository.swift
//  ThawabForGod
//

import Foundation

/// Serves prayer times from on-device computation.
///
/// It is a pass-through today, and that is the point: because times are computed rather than
/// fetched, there is nothing to cache and no network to fall back from. The type exists so
/// callers depend on `PrayerTimeRepositoring` instead of the engine, which is what will let a
/// precomputed year or a bundled table slot in later without changing a single use case.
nonisolated struct PrayerTimeRepository: PrayerTimeRepositoring {
    private let engine: any PrayerTimeCalculating

    init(engine: any PrayerTimeCalculating) {
        self.engine = engine
    }

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        try engine.schedule(for: coordinates, date: date, config: config)
    }
}
