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
    private var coordinatesLog: [Coordinates] = []

    init(schedules: [Date: PrayerSchedule]) {
        self.schedules = schedules
    }

    /// Every config asked for, in order.
    var requestedConfigs: [CalculationConfig] {
        lock.withLock { configs }
    }

    /// Every point asked for, in order — what a live location fix actually reached the
    /// calculation with, as opposed to what the view model was merely constructed with.
    var requestedCoordinates: [Coordinates] {
        lock.withLock { coordinatesLog }
    }

    func schedule(
        for coordinates: Coordinates,
        date: Date,
        config: CalculationConfig
    ) throws -> PrayerSchedule {
        lock.withLock {
            configs.append(config)
            coordinatesLog.append(coordinates)
        }

        guard let schedule = schedules[PrayerTimeFixtures.calendar.startOfDay(for: date)] else {
            throw PrayerTimeError.notComputable(date)
        }

        return schedule
    }
}

/// A clock the test moves by hand.
///
/// It is a `ClockService`, so the view model under test cannot tell it from the real one — but
/// nothing here ever sleeps. `advance(by:)` moves the time; `tick(after:)` moves it *and*
/// delivers a beat to whatever is iterating `ticks(every:)`, which is how a countdown is stepped
/// a second at a time in a test that finishes in microseconds.
///
/// Safety invariant for `@unchecked Sendable`: every stored property is touched only under
/// `lock`. The lock is real rather than ceremonial — `AsyncStream`'s termination handler runs on
/// whatever context tore the stream down, not on the test's actor.
nonisolated final class TestClock: ClockService, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    private var continuations: [UUID: AsyncStream<Date>.Continuation] = [:]

    init(_ value: Date) {
        self.value = value
    }

    var now: Date { lock.withLock { value } }

    /// Whether anything is currently iterating `ticks(every:)`.
    ///
    /// A test that beats the clock before the view model has started listening would yield into
    /// nothing and then wait forever for a change that already happened — so tests spin on this
    /// first. It is the price of a stream that only exists once somebody asks for it.
    var isTicking: Bool { lock.withLock { !continuations.isEmpty } }

    /// The interval is ignored: a hand-driven clock beats when the test says so, and honouring
    /// it would be the one thing this type exists to avoid.
    func ticks(every interval: Duration) -> AsyncStream<Date> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.withLock { _ = self.continuations.removeValue(forKey: id) }
            }
        }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { value += interval }
    }

    func move(to date: Date) {
        lock.withLock { value = date }
    }

    /// Moves the clock and beats once, which is what a real second does.
    func tick(after interval: TimeInterval) {
        let instant: Date = lock.withLock {
            value += interval
            return value
        }

        for continuation in lock.withLock({ Array(continuations.values) }) {
            continuation.yield(instant)
        }
    }
}
