//
//  HijriDate.swift
//  ThawabForGod
//

import Foundation

/// A day in the Hijri calendar, as numbers and a month — never as text.
///
/// Rendering is the presentation layer's job: the month becomes a word through `L10nKey`, the
/// day and year become digits through `NumberFormattingService`. Keeping this entity free of
/// strings is what lets one value serve Arabic and English, Arabic-Indic and Latin digits,
/// without the service knowing which is selected.
nonisolated struct HijriDate: Equatable, Sendable {
    let day: Int
    let month: HijriMonth
    let year: Int

    init(day: Int, month: HijriMonth, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }
}

/// The twelve Hijri months, numbered as Foundation numbers them.
///
/// The raw values are 1–12 on purpose: they are what `Calendar.dateComponents` reports and
/// what the bundled events table stores, so no lookup table stands between the three.
nonisolated enum HijriMonth: Int, CaseIterable, Identifiable, Sendable, Codable {
    case muharram = 1
    case safar
    case rabiAlAwwal
    case rabiAlThani
    case jumadaAlUla
    case jumadaAlAkhirah
    case rajab
    case shaban
    case ramadan
    case shawwal
    case dhulQadah
    case dhulHijjah

    var id: Int { rawValue }

    var labelKey: L10nKey {
        switch self {
        case .muharram: .hijriMonthMuharram
        case .safar: .hijriMonthSafar
        case .rabiAlAwwal: .hijriMonthRabiAlAwwal
        case .rabiAlThani: .hijriMonthRabiAlThani
        case .jumadaAlUla: .hijriMonthJumadaAlUla
        case .jumadaAlAkhirah: .hijriMonthJumadaAlAkhirah
        case .rajab: .hijriMonthRajab
        case .shaban: .hijriMonthShaban
        case .ramadan: .hijriMonthRamadan
        case .shawwal: .hijriMonthShawwal
        case .dhulQadah: .hijriMonthDhulQadah
        case .dhulHijjah: .hijriMonthDhulHijjah
        }
    }
}
