//
//  PrayerTimeRepositoring.swift
//  ThawabForGod
//

import Foundation

/// Where a day's prayer times come from.
///
/// Today the only source is on-device computation, so the implementation is a thin pass to
/// the engine. The protocol still earns its place: it is the seam use cases are tested
/// against, and it is where a cached or precomputed year would slot in without any caller
/// noticing.
nonisolated protocol PrayerTimeRepositoring: Sendable {
    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule
}
