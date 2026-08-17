//
//  PrayerTimeFixtures.swift
//  ThawabForGodTests
//

import Foundation
@testable import ThawabForGod

/// A fixed day of prayer times, and a repository that serves them.
///
/// Everything is pinned to UTC and to round hours. Real Adhan output would make these tests
/// depend on astronomy and on the machine's time zone; what is under test here is the
/// roll-over logic, so the numbers only need to be ordered and predictable.
enum PrayerTimeFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// fajr 05:00 · sunrise 06:30 · dhuhr 12:00 · asr 15:30 · maghrib 18:00 · isha 19:30
    static let offsets: [(prayer: Prayer, hour: Int, minute: Int)] = [
        (.fajr, 5, 0),
        (.sunrise, 6, 30),
        (.dhuhr, 12, 0),
        (.asr, 15, 30),
        (.maghrib, 18, 0),
        (.isha, 19, 30)
    ]

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func instant(_ day: Date, hour: Int, minute: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    static func schedule(on day: Date) -> PrayerSchedule {
        PrayerSchedule(
            day: day,
            times: offsets.map {
                PrayerTime(prayer: $0.prayer, date: instant(day, hour: $0.hour, minute: $0.minute))
            }
        )
    }

    static func repository(days: [Date]) -> StubPrayerTimeRepository {
        StubPrayerTimeRepository(
            schedules: Dictionary(uniqueKeysWithValues: days.map { ($0, schedule(on: $0)) })
        )
    }
}

/// Serves prepared schedules by day, or fails on demand.
///
/// A stub rather than a spy: none of these tests care how often the repository was asked,
/// only what it answered.
nonisolated struct StubPrayerTimeRepository: PrayerTimeRepositoring {
    /// Keyed by the start of the day each schedule covers.
    var schedules: [Date: PrayerSchedule] = [:]

    /// When set, every call throws this instead of answering.
    var failure: PrayerTimeError?

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        if let failure {
            throw failure
        }

        guard let schedule = schedules[PrayerTimeFixtures.calendar.startOfDay(for: date)] else {
            throw PrayerTimeError.notComputable(date)
        }

        return schedule
    }
}

/// The same stub, but recording what it was asked with.
///
/// A class rather than a struct because the recording has to survive being copied into a use case
/// — and `@unchecked Sendable` over a lock for the same reason `SpyHomeTipReporter` is: the
/// protocol is `nonisolated`, so no actor could witness it.
///
/// It exists for one question the value-type stub cannot answer: whether a config changed in
/// Settings actually reaches the calculation.
nonisolated final class RecordingPrayerTimeRepository: PrayerTimeRepositoring, @unchecked Sendable {
    private let lock = NSLock()
    private let schedules: [Date: PrayerSchedule]
    private var configs: [CalculationConfig] = []

    init(schedules: [Date: PrayerSchedule]) {
        self.schedules = schedules
    }

    /// Every config asked for, in order.
    var requestedConfigs: [CalculationConfig] {
        lock.withLock { configs }
    }

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        lock.withLock { configs.append(config) }

        guard let schedule = schedules[PrayerTimeFixtures.calendar.startOfDay(for: date)] else {
            throw PrayerTimeError.notComputable(date)
        }

        return schedule
    }
}

/// A clock the test moves by hand.
///
/// Safety invariant for `@unchecked Sendable`: it is only ever touched from the test's main
/// actor — the suites are `@MainActor`, and the view model reads the clock from there too.
/// The `@Sendable` closure is required by `HomeViewModel`'s initializer, not by any real
/// concurrency here.
nonisolated final class TestClock: @unchecked Sendable {
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    var now: Date { value }

    /// Captures the clock strongly on purpose: tests that only need the view model discard
    /// their reference to it, and the clock has to outlive that.
    var provider: @Sendable () -> Date {
        { self.value }
    }

    func advance(by interval: TimeInterval) {
        value += interval
    }

    func move(to date: Date) {
        value = date
    }
}
