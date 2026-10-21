//
//  MoonPhaseCalculating.swift
//  ThawabForGod
//

import Foundation

/// Where the Moon is in its cycle, computed locally.
nonisolated protocol MoonPhaseCalculating: Sendable {
    func info(at date: Date) -> MoonInfo

    /// The most recent new moon at or before `date`.
    func lastNewMoon(onOrBefore date: Date) -> Date
    func nextNewMoon(after date: Date) -> Date
    func nextFullMoon(after date: Date) -> Date
}
