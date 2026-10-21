//
//  HijriDayOffset.swift
//  ThawabForGod
//

import Foundation

/// The reader's correction to the calculated Hijri date, in whole days.
///
/// Umm al-Qura is a table; a community that follows local sighting can be a day either side of
/// it. The offset is the one knob for that, and it is clamped here so a stray stored value can
/// never move the calendar by a week.
nonisolated enum HijriDayOffset {
    static let range = -2...2

    static func clamp(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The stored offset, or 0 when the reader never chose one. A stored `0` and "unset" mean
    /// the same thing, so unlike most preferences nothing is lost by the distinction collapsing.
    static func current(in store: any SettingsStore) -> Int {
        clamp(Int((store.double(for: .hijriDayOffset) ?? 0).rounded()))
    }
}
