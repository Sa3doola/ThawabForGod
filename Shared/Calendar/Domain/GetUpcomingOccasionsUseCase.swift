//
//  GetUpcomingOccasionsUseCase.swift
//  ThawabForGod
//

import Foundation

/// The next occasions from a date, wrapping into the following Hijri year when the current one
/// runs out.
///
/// Recurring occasions (the White Days, Monday and Thursday) are left out unless asked for: two
/// of them a week would bury the dozen that are only once a year. An occasion already under way
/// — a range whose last day has not passed — is still upcoming.
nonisolated struct GetUpcomingOccasionsUseCase: Sendable {
    let resolve: ResolveOccasionDatesUseCase
    let calendar: any HijriCalendarServicing
    var gregorian: Calendar = .gregorianLocal

    func callAsFunction(
        from date: Date,
        limit: Int,
        includeRecurring: Bool = false,
        categories: Set<OccasionCategory> = Set(OccasionCategory.allCases)
    ) -> [OccasionOccurrence] {
        let today = gregorian.startOfDay(for: date)
        let year = calendar.monthKey(containing: date).year
        let pool = resolve(hijriYear: year) + resolve(hijriYear: year + 1)
        return Array(
            pool
                .filter { $0.last.gregorian >= today }
                .filter { includeRecurring || !$0.occasion.isRecurring }
                .filter { categories.contains($0.occasion.category) }
                .prefix(max(limit, 0))
        )
    }
}
