//
//  PrayerTrackerUseCase.swift
//  ThawabForGod
//

import Foundation

/// What the tracker screens do with the record: read a day, mark a prayer, count the streak.
///
/// The streak is the only real logic here, and it lives in Domain rather than in a view model
/// because it is a rule about days rather than about a screen — and because it is the one part of
/// this feature that is easy to get subtly wrong.
nonisolated struct PrayerTrackerUseCase: Sendable {

    /// How far back a streak is counted. Long enough that nobody will reach it, short enough that
    /// the read stays a bounded number of rows rather than the whole store.
    static let streakWindow = 365

    private let repository: any PrayerTrackerRepositoring
    private let calendar: Calendar

    init(
        repository: any PrayerTrackerRepositoring,
        calendar: Calendar = .gregorianLocal
    ) {
        self.repository = repository
        self.calendar = calendar
    }

    func record(on date: Date) async throws -> PrayerRecord {
        try await repository.record(on: calendar.startOfDay(for: date))
    }

    func setCompleted(_ isCompleted: Bool, of prayer: Prayer, on date: Date) async throws {
        let day = calendar.startOfDay(for: date)
        let record = try await repository.record(on: day)

        try await repository.save(record.setting(prayer, to: isCompleted))
    }

    /// How many days in a row, ending today, have all five marked.
    ///
    /// **Today not being complete does not break the streak.** It is the middle of the day for
    /// somebody: a run counted to yesterday is still a run, and zeroing it at Fajr every morning
    /// would make the number useless. So the count starts at today if today is complete, and at
    /// yesterday otherwise — and stops at the first day that is not.
    func streak(endingOn date: Date) async throws -> Int {
        let today = calendar.startOfDay(for: date)

        guard let start = calendar.date(byAdding: .day, value: -Self.streakWindow, to: today)
        else {
            return 0
        }

        let complete = Set(
            try await repository.records(from: start, to: today)
                .filter(\.isComplete)
                .map(\.day)
        )

        var day = complete.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)
        var count = 0

        while let current = day, complete.contains(current) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: current)
        }

        return count
    }
}
