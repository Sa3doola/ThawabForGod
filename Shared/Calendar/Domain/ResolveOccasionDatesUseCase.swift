//
//  ResolveOccasionDatesUseCase.swift
//  ThawabForGod
//

import Foundation
import os

/// One happening of an occasion: a run of days that belong together.
nonisolated struct OccasionOccurrence: Identifiable, Equatable, Sendable {
    nonisolated struct Day: Equatable, Sendable {
        let hijri: HijriDate
        let gregorian: Date
    }

    let occasion: IslamicOccasion
    let days: [Day]

    var first: Day { days[0] }
    var last: Day { days[days.count - 1] }
    var id: String { "\(occasion.id).\(first.hijri.year).\(first.hijri.month.rawValue).\(first.hijri.day)" }
}

/// Turns rules into dates for one Hijri year, on the Umm al-Qura calendar and the reader's offset.
///
/// Everything comes from `HijriCalendarServicing`'s month grids, so the offset is applied in the
/// one place it already is. A range that runs past the month's last day simply stops there.
/// Results are cached per year *and* per offset: a change in Settings must not serve stale dates.
nonisolated final class ResolveOccasionDatesUseCase: @unchecked Sendable {

    private struct CacheKey: Hashable { let year: Int; let offset: Int }

    private let repository: any IslamicOccasionsRepositoring
    private let calendar: any HijriCalendarServicing
    private let dayOffset: @Sendable () -> Int
    private let cache = OSAllocatedUnfairLock(initialState: [CacheKey: [OccasionOccurrence]]())

    init(
        repository: any IslamicOccasionsRepositoring,
        calendar: any HijriCalendarServicing,
        dayOffset: @escaping @Sendable () -> Int = { 0 }
    ) {
        self.repository = repository
        self.calendar = calendar
        self.dayOffset = dayOffset
    }

    /// Every occurrence in the year, earliest first.
    func callAsFunction(hijriYear: Int) -> [OccasionOccurrence] {
        let key = CacheKey(year: hijriYear, offset: HijriDayOffset.clamp(dayOffset()))
        if let cached = cache.withLock({ $0[key] }) { return cached }

        let occasions = repository.occasions()
        var result: [OccasionOccurrence] = []
        for month in HijriMonth.allCases {
            guard let grid = calendar.monthGrid(for: HijriMonthKey(year: hijriYear, month: month), firstWeekday: 1)
            else { continue }
            for occasion in occasions {
                let days = grid.days
                    .filter { occasion.rule.matches(month: month.rawValue, day: $0.number, weekday: $0.weekday) }
                    .map { OccasionOccurrence.Day(
                        hijri: HijriDate(day: $0.number, month: month, year: hijriYear), gregorian: $0.gregorian) }
                guard !days.isEmpty else { continue }
                if case .weekly = occasion.rule {
                    result += days.map { OccasionOccurrence(occasion: occasion, days: [$0]) }
                } else {
                    result.append(OccasionOccurrence(occasion: occasion, days: days))
                }
            }
        }
        result.sort { $0.first.gregorian < $1.first.gregorian }
        let resolved = result
        cache.withLock { $0[key] = resolved }
        return resolved
    }
}
