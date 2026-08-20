//
//  PrayerTimesSheetViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// Drives the full day: any date's times, what was prayed on it, and how the night divides.
///
/// A view model of its own rather than more properties on `HomeViewModel`, because it has a piece
/// of state Home deliberately does not — **a selected date**. Home is always about now; this is
/// the screen where the user goes looking, and folding a date into Home would mean every one of
/// its sections had to decide whether it followed the clock or the picker.
@Observable
@MainActor
final class PrayerTimesSheetViewModel {

    enum Phase: Equatable {
        case loading
        case ready(PrayerSchedule)
        /// The polar case, for a date rather than for today.
        case unavailable
    }

    private(set) var phase: Phase = .loading

    /// The day on screen, at midnight.
    private(set) var day: Date {
        didSet { hijriDate = hijriDates.hijriComponents(for: day) }
    }

    /// The same day in the Hijri calendar, kept in step with it.
    ///
    /// Here rather than read from the environment by the view, because the stepper shows the date
    /// *being browsed* rather than today's — and a view that reached for the service itself would
    /// have to remember that distinction on every redraw.
    private(set) var hijriDate: HijriDate

    /// What was marked on that day, and how many days in a row have been complete.
    private(set) var record: PrayerRecord
    private(set) var streak = 0

    /// Which prayer's explanation is open, or `nil`. On the view model rather than as `@State`
    /// so it survives the list redrawing under it when a circle is tapped.
    var explaining: Prayer?

    @ObservationIgnored private let useCase: GetPrayerScheduleUseCase
    @ObservationIgnored private let tracker: PrayerTrackerUseCase?
    @ObservationIgnored private let calculation: CalculationSettings
    @ObservationIgnored private let hijriDates: any HijriDateServicing
    @ObservationIgnored private let coordinates: @MainActor () -> Coordinates
    @ObservationIgnored private let clock: any ClockService
    @ObservationIgnored private let calendar: Calendar

    /// - Parameters:
    ///   - coordinates: read on each load rather than captured, so a live fix that arrives while
    ///     Home is open reaches this screen the next time it is opened. A closure rather than a
    ///     stored value for exactly that reason.
    ///   - tracker: `nil` leaves the completion circles out, which is what previews and the tests
    ///     about the date stepper want.
    init(
        useCase: GetPrayerScheduleUseCase,
        tracker: PrayerTrackerUseCase? = nil,
        calculation: CalculationSettings,
        hijriDates: any HijriDateServicing,
        coordinates: @escaping @MainActor () -> Coordinates,
        clock: any ClockService = SystemClockService(),
        calendar: Calendar = .gregorianLocal
    ) {
        self.useCase = useCase
        self.tracker = tracker
        self.calculation = calculation
        self.hijriDates = hijriDates
        self.coordinates = coordinates
        self.clock = clock
        self.calendar = calendar

        let today = calendar.startOfDay(for: clock.now)
        self.day = today
        self.record = PrayerRecord(day: today)
        self.hijriDate = hijriDates.hijriComponents(for: today)
    }

    /// The prayer being counted down to, but only while the day on screen is today.
    ///
    /// A badge saying "next" on a day three weeks out would be nonsense — every prayer on it is
    /// still to come. So this is `nil` on any other day, and the badge simply does not appear.
    var upcomingPrayer: Prayer? {
        guard isToday, case .ready(let schedule) = phase else { return nil }
        return schedule.nextPrayer(at: clock.now)?.prayer
    }

    /// Whether the day on screen is the day it is — what the "today" button is enabled by.
    var isToday: Bool {
        calendar.isDate(day, inSameDayAs: clock.now)
    }

    // MARK: The date stepper

    func showPreviousDay() {
        move(by: -1)
    }

    func showNextDay() {
        move(by: 1)
    }

    func showToday() {
        day = calendar.startOfDay(for: clock.now)
    }

    private func move(by days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: day) else { return }
        day = calendar.startOfDay(for: moved)
    }

    // MARK: Loading

    /// Computes the shown day and reads what was marked on it.
    ///
    /// Driven from a `.task(id: day)`, so stepping the date re-runs it and closing the sheet
    /// cancels it — there is no stored task here and nothing to cancel by hand.
    func load() async {
        do {
            phase = .ready(
                try useCase.schedule(for: coordinates(), date: day, config: calculation.config)
            )
        } catch {
            phase = .unavailable
        }

        await loadRecord()
    }

    /// Marks or unmarks one prayer on the shown day.
    ///
    /// The screen moves first and the store follows, and the write is re-read afterwards rather
    /// than assumed: a tap is on a circle the user is looking at, and a mark that filled in only
    /// once SwiftData had saved would lag behind the finger — the same trade the Quran's
    /// bookmarks make.
    func setCompleted(_ isCompleted: Bool, of prayer: Prayer) async {
        guard let tracker else { return }

        record = record.setting(prayer, to: isCompleted)

        try? await tracker.setCompleted(isCompleted, of: prayer, on: day)
        await loadRecord()
    }

    private func loadRecord() async {
        guard let tracker else { return }

        record = (try? await tracker.record(on: day)) ?? PrayerRecord(day: day)
        streak = (try? await tracker.streak(endingOn: clock.now)) ?? 0
    }
}
