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
    @ObservationIgnored private let reminders: ReminderPreferences?
    @ObservationIgnored private let hijriDates: any HijriDateServicing
    @ObservationIgnored private let coordinates: @MainActor () -> Coordinates
    @ObservationIgnored private let clock: any ClockService
    @ObservationIgnored private let calendar: Calendar

    /// - Parameters:
    ///   - coordinates: read on each load rather than captured, so a live fix that arrives while
    ///     Home is open reaches this screen the next time it is opened. A closure rather than a
    ///     stored value for exactly that reason.
    ///   - tracker: `nil` leaves the completion circles out, which is what previews and the tests
    ///     about the date picker want.
    ///   - reminders: `nil` leaves the bells out. Read-only here — this screen *reports* which
    ///     prayers are set to remind, and Settings is where that is changed; a switch in two
    ///     places is two places to look when the wrong one is on.
    init(
        useCase: GetPrayerScheduleUseCase,
        tracker: PrayerTrackerUseCase? = nil,
        calculation: CalculationSettings,
        reminders: ReminderPreferences? = nil,
        hijriDates: any HijriDateServicing,
        coordinates: @escaping @MainActor () -> Coordinates,
        clock: any ClockService = SystemClockService(),
        calendar: Calendar = .gregorianLocal
    ) {
        self.useCase = useCase
        self.tracker = tracker
        self.calculation = calculation
        self.reminders = reminders
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

    /// How a prayer stands in the day on screen — the one value the row's leading dot is drawn
    /// from, so the four states cannot overlap or be drawn in the wrong order of precedence.
    ///
    /// **Logged outranks everything.** A prayer that was prayed is prayed whether or not it has
    /// since gone past, and a reader scanning the column of dots is looking for the gaps.
    enum Standing {
        case logged
        /// The one being counted down to. Only ever on today — see `upcomingPrayer`.
        case next
        case passed
        case upcoming
    }

    func standing(of time: PrayerTime) -> Standing {
        if time.prayer.isObligatory, record.isCompleted(time.prayer) { return .logged }
        if upcomingPrayer == time.prayer { return .next }
        // A day in the past is entirely passed and a day in the future entirely to come; only
        // today is cut by the clock.
        if day < calendar.startOfDay(for: clock.now) { return .passed }
        if isToday, time.date <= clock.now { return .passed }
        return .upcoming
    }

    /// How far off a prayer is, or `nil` where saying so would be noise.
    ///
    /// Only on today, and only for what is still to come: "in 4h 34m" is a useful thing to know
    /// about this evening's Maghrib and a meaningless one about a Tuesday three weeks out, where
    /// every prayer is equally far away and the number would just be the date restated six times.
    func remaining(until time: PrayerTime) -> TimeInterval? {
        guard isToday else { return nil }

        let interval = time.date.timeIntervalSince(clock.now)
        return interval > 0 ? interval : nil
    }

    /// Whether a reminder is set for this prayer. `nil` where the screen has no reminders to
    /// report on — previews and tests — so the bell is absent rather than drawn as "off".
    func isReminding(_ prayer: Prayer) -> Bool? {
        guard let reminders, prayer.isObligatory else { return nil }
        return reminders.isEnabled(prayer)
    }

    /// Whether the day on screen is the day it is — what the "today" button is enabled by.
    var isToday: Bool {
        calendar.isDate(day, inSameDayAs: clock.now)
    }

    // MARK: The date picker

    /// The seven days the strip draws, in the order the user's calendar runs them.
    ///
    /// Built from `firstWeekday` rather than assumed to start on a Sunday or a Monday: the week
    /// begins on a different day in different places, and a strip that always began on Sunday
    /// would put the weekend in the middle for a reader whose week does not.
    ///
    /// Recomputed on every read rather than stored. It is seven `date(byAdding:)` calls, and the
    /// alternative — a cached array kept in step with `day` — is a second piece of state that can
    /// disagree with the first.
    var week: [Date] {
        let weekday = calendar.component(.weekday, from: day)
        // How far back the shown day is from the start of its own week, wrapped into 0...6 so
        // the arithmetic holds whichever weekday the calendar starts on.
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        guard let start = calendar.date(byAdding: .day, value: -offset, to: day) else { return [day] }

        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Whether a day in the strip is the one being shown, and whether it is the day it is. Two
    /// questions rather than one, because the strip answers them with two different marks — a
    /// filled tile for the selection, a rule under the numeral for today — and a day can be
    /// either, both or neither.
    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: day)
    }

    func isCurrentDay(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: clock.now)
    }

    func select(_ date: Date) {
        day = calendar.startOfDay(for: date)
    }

    /// The chevrons flanking the strip page a **week**, not a day.
    ///
    /// A strip already shows seven days, so a chevron that moved one of them would mostly slide
    /// the selection along tiles the reader can simply tap. Paging is the thing the strip cannot
    /// do for itself.
    func showPreviousWeek() {
        move(by: -7)
    }

    func showNextWeek() {
        move(by: 7)
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
