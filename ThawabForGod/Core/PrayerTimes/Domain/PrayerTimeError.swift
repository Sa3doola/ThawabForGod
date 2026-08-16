//
//  PrayerTimeError.swift
//  ThawabForGod
//

import Foundation

/// Why a day's times could not be produced.
///
/// There is no network case here on purpose: prayer times are computed on device, so the only
/// way this fails is geometry.
nonisolated enum PrayerTimeError: Error, Equatable, Sendable {
    /// The sun's path has no solution for this place on this day — the polar regions in
    /// midsummer or midwinter, where it never rises or never sets.
    case notComputable(Date)

    /// A calendar could not produce the requested day. Effectively unreachable, but the
    /// alternative is force-unwrapping a date.
    case invalidDate(Date)
}
