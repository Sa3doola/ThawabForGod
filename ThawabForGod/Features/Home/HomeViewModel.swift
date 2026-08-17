//
//  HomeViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the Home screen: today's times, which prayer is current, which is next, and a
/// countdown that ticks once a second.
///
/// It holds no astronomy of its own — that all lives behind `GetPrayerScheduleUseCase`, which
/// is what lets this type be tested by handing it a mock repository and a fake clock instead
/// of waiting on a real one.
@Observable
@MainActor
final class HomeViewModel {

    /// What the screen has to show. A single value rather than a scatter of optionals and
    /// flags, so the view can `switch` over it and no impossible combination is representable.
    enum Phase: Equatable {
        case loading
        case ready(Day)
        /// The times could not be computed — the polar case. Not an error the user can fix,
        /// so it is a state rather than an alert.
        case unavailable
    }

    struct Day: Equatable {
        let schedule: PrayerSchedule
        let currentPrayer: Prayer?
        let upcoming: UpcomingPrayer

        func isCurrent(_ prayer: Prayer) -> Bool {
            currentPrayer == prayer
        }

        /// Whether this row is the one being counted down to.
        ///
        /// The `isTomorrow` guard is the whole point: after Isha the countdown targets the
        /// *next* day's Fajr, and marking today's Fajr row as "next" would be a lie.
        func isUpcoming(_ prayer: Prayer) -> Bool {
            !upcoming.isTomorrow && upcoming.prayer == prayer
        }
    }

    private(set) var phase: Phase = .loading

    /// Seconds remaining until the upcoming prayer.
    ///
    /// Kept apart from `phase` deliberately. Observation tracks reads per property, so a
    /// value that changes every second only invalidates the one label that reads it — the
    /// six-row list is left alone.
    private(set) var countdown: TimeInterval = 0

    /// Today's Hijri date, and anything the Islamic calendar marks on it.
    ///
    /// Outside `Phase` on purpose: the times can fail to compute — the polar case — and the
    /// date still holds. A screen that says "prayer times unavailable" should not also lose
    /// track of what day it is.
    private(set) var hijriDate: HijriDate
    private(set) var todaysEvents: [IslamicEvent]

    /// How the times are being calculated right now.
    ///
    /// A window onto `CalculationSettings` rather than a copy, and the reason it is exposed at
    /// all: reading it inside a view registers a dependency on the shared object, so the view
    /// can watch it with `onChange` and ask for a recompute when Settings changes it. A stored
    /// copy would observe nothing.
    var config: CalculationConfig { calculation.config }

    @ObservationIgnored private let useCase: GetPrayerScheduleUseCase
    @ObservationIgnored private let coordinates: Coordinates
    @ObservationIgnored private let calculation: CalculationSettings
    @ObservationIgnored private let hijriDates: any HijriDateServicing
    @ObservationIgnored private let tips: any HomeTipReporting
    @ObservationIgnored private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - coordinates: injected, never assumed. Today the container supplies a fixed point;
    ///     when the location slice lands only that one line changes.
    ///   - calculation: the shared calculation choices. Not a plain `CalculationConfig`, because
    ///     Settings can change it while this screen is alive.
    ///   - hijriDates: the Hijri conversion and the events table.
    ///   - tips: where TipKit's rule inputs are reported. Behind a protocol so this type never
    ///     imports TipKit and its tests never open a datastore.
    ///   - now: the clock, injected so tests can place themselves at any moment of the day.
    init(
        useCase: GetPrayerScheduleUseCase,
        coordinates: Coordinates,
        hijriDates: any HijriDateServicing,
        calculation: CalculationSettings,
        tips: any HomeTipReporting = HomeTipReporter(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.useCase = useCase
        self.coordinates = coordinates
        self.calculation = calculation
        self.hijriDates = hijriDates
        self.tips = tips
        self.now = now

        // Resolved here rather than left optional: unlike the schedule, the Hijri date needs
        // no computation that can fail, so the screen has one from its first frame and the
        // header never flickers in behind the loading state.
        let instant = now()
        self.hijriDate = hijriDates.hijriComponents(for: instant)
        self.todaysEvents = hijriDates.islamicEvents(on: instant)
    }

    /// Loads the day, then ticks until cancelled.
    ///
    /// Structured on purpose: driven from the view's `.task`, SwiftUI cancels it when the
    /// screen goes away, so there is no stored `Task` to own, no `[weak self]` dance, and no
    /// timer left running behind a screen nobody is looking at.
    func start() async {
        refresh()

        // One donation per appearance, which is what the "opened a few times" tip rule counts.
        // Before the loop, so a screen that is dismissed immediately still records the visit.
        await tips.homeOpened()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return // cancelled — the screen is gone
            }
            tick()
        }
    }

    /// Recomputes everything from the current instant.
    func refresh() {
        let instant = now()

        // Ahead of the schedule, and outside the `do`: the date is what the day is, whether or
        // not the times worked out. It also lets the roll into a new day — which `tick()`
        // triggers by calling back into here — carry the header along with the times.
        hijriDate = hijriDates.hijriComponents(for: instant)
        todaysEvents = hijriDates.islamicEvents(on: instant)

        do {
            let schedule = try useCase.schedule(for: coordinates, date: instant, config: config)
            let upcoming = try useCase.upcomingPrayer(for: coordinates, at: instant, config: config)

            phase = .ready(
                Day(
                    schedule: schedule,
                    currentPrayer: schedule.currentPrayer(at: instant),
                    upcoming: upcoming
                )
            )
            countdown = max(0, upcoming.date.timeIntervalSince(instant))
            // Reported here rather than read by the tip, so eligibility is a plain flag and
            // TipKit never learns what a prayer schedule is.
            tips.countingDownToTomorrow(upcoming.isTomorrow)
        } catch {
            phase = .unavailable
            countdown = 0
            tips.countingDownToTomorrow(false)
        }
    }

    /// Advances the countdown by one reading of the clock.
    ///
    /// Internal rather than private so tests can step time deliberately instead of sleeping.
    func tick() {
        guard case .ready(let day) = phase else { return }

        let remaining = day.upcoming.date.timeIntervalSince(now())

        if remaining > 0 {
            countdown = remaining
        } else {
            // The prayer has arrived. A full refresh moves the highlight and retargets the
            // countdown — including the roll into tomorrow's Fajr once Isha passes.
            refresh()
        }
    }
}
