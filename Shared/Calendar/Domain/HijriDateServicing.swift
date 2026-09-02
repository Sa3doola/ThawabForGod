//
//  HijriDateServicing.swift
//  ThawabForGod
//

import Foundation

/// Converts an instant to its Hijri date, and answers what falls on it.
///
/// `nonisolated` and `Sendable`: this is pure value logic over a calendar table with no state
/// to protect, so it runs wherever the caller already is — the view model calls it
/// synchronously on the main actor, and a future notification scheduler can call it from a
/// background task without an actor hop.
nonisolated protocol HijriDateServicing: Sendable {
    func hijriComponents(for date: Date) -> HijriDate

    /// Every event sharing the given date's Hijri day and month. Empty on most days.
    func islamicEvents(on date: Date) -> [IslamicEvent]
}
