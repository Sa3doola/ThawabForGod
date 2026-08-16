//
//  PrayerTimeCalculating.swift
//  ThawabForGod
//

import Foundation

/// The prayer-times engine, as the rest of the app sees it.
///
/// One protocol covers both features that need the same astronomy: today's times, and the
/// Qibla bearing. Keeping them together is what stops the Qibla slice from growing a second,
/// subtly different copy of the maths.
///
/// Synchronous by design. This is arithmetic over a handful of angles — there is nothing to
/// await, and making it `async` would only add ceremony. `nonisolated` so a caller off the
/// main actor (a notification scheduler, say) can use it directly.
nonisolated protocol PrayerTimeCalculating: Sendable {
    /// The times for the civil day that `date` falls in.
    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule

    /// The heading to the Kaaba from `coordinates`, in degrees clockwise from true north.
    func qiblaBearing(from coordinates: Coordinates) -> Double
}
