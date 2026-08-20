//
//  NightTimes.swift
//  ThawabForGod
//

import Foundation

/// The two marks the night is divided at, between Maghrib and the following Fajr.
///
/// Not prayers, and deliberately not on `Prayer`'s timeline: nothing begins at either of them.
/// They matter because the night prayer is recommended in the last third, and because "midnight"
/// in this sense is the midpoint between sunset and dawn rather than 00:00 — which is exactly the
/// sort of thing a user cannot work out from a list of six times and reasonably expects the app
/// to have done for them.
nonisolated struct NightTimes: Equatable, Sendable {
    /// Halfway between Maghrib and the next Fajr — the end of Isha's window on the majority view.
    let middleOfNight: Date

    /// Where the last third begins.
    let lastThirdOfNight: Date

    init(middleOfNight: Date, lastThirdOfNight: Date) {
        self.middleOfNight = middleOfNight
        self.lastThirdOfNight = lastThirdOfNight
    }
}
