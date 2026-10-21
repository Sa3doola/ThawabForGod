//
//  MoonInfo.swift
//  ThawabForGod
//

import Foundation

/// The eight named phases, in the order the Moon passes through them.
nonisolated enum MoonPhase: CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous,
         fullMoon, waningGibbous, lastQuarter, waningCrescent

    /// The phase whose 45° wedge, centred on a multiple of 45°, contains the elongation.
    init(elongationDegrees: Double) {
        let wrapped = elongationDegrees.truncatingRemainder(dividingBy: 360)
        let normalized = wrapped < 0 ? wrapped + 360 : wrapped
        let index = Int(((normalized + 22.5) / 45).rounded(.down)) % 8
        self = Self.allCases[index]
    }

    var labelKey: L10nKey {
        switch self {
        case .newMoon: .moonPhaseNewMoon
        case .waxingCrescent: .moonPhaseWaxingCrescent
        case .firstQuarter: .moonPhaseFirstQuarter
        case .waxingGibbous: .moonPhaseWaxingGibbous
        case .fullMoon: .moonPhaseFullMoon
        case .waningGibbous: .moonPhaseWaningGibbous
        case .lastQuarter: .moonPhaseLastQuarter
        case .waningCrescent: .moonPhaseWaningCrescent
        }
    }

    /// The elongation at the centre of this phase's wedge.
    var centerElongation: Double { Double(Self.allCases.firstIndex(of: self)!) * 45 }
}

/// What the Moon looks like at one instant, as numbers.
nonisolated struct MoonInfo: Equatable, Sendable {
    let date: Date
    let phase: MoonPhase
    /// 0…1.
    let illuminatedFraction: Double
    /// 0..<360. 0 is new, 180 is full.
    let elongationDegrees: Double
    let isWaxing: Bool
    /// Days since the last new moon.
    let ageInDays: Double
    let distanceKm: Double
}
