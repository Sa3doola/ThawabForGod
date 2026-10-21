//
//  HijriCalendarViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// What a day in the grid has on it, for the dot under its number.
nonisolated struct DayMarker: Equatable, Sendable {
    /// An occasion that falls on this day once a year (or once a lunation) — the loud dot.
    var hasOccasion = false
    /// Only a recurring one — Mondays, the White Days — which gets the quieter dot.
    var hasRecurring = false
}

/// The one occasion Home's card mentions.
nonisolated enum CardOccasion: Equatable, Sendable {
    case today(IslamicOccasion)
    case upcoming(IslamicOccasion, days: Int)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.today(let a), .today(let b)): a.id == b.id
        case (.upcoming(let a, let x), .upcoming(let b, let y)): a.id == b.id && x == y
        default: false
        }
    }
}

/// State for the Hijri calendar screen: which month is showing, which day is selected, and what
/// each day carries.
///
/// The grid itself is never stored. A month is thirty cells and `HijriCalendarService` builds it
/// from Foundation's table, so computing it where it is drawn is cheaper than keeping a cache
/// that the Hijri offset or the week start would have to invalidate.
@Observable
@MainActor
final class HijriCalendarViewModel {

    /// The month the pager is on.
    private(set) var visibleMonth: HijriMonthKey

    /// The selected civil day, as the start of that day.
    private(set) var selectedDay: Date

    /// Whether each cell also shows its Gregorian number. Written through only when it changes,
    /// because a stored preference outranks the default for good.
    var showGregorian: Bool {
        didSet {
            guard showGregorian != oldValue else { return }
            settingsStore.set(showGregorian, for: .showGregorianInCalendar)
        }
    }

    /// Whether the quiet dots for recurring fasts are drawn on the grid.
    var hideRecurringDots: Bool {
        didSet {
            guard hideRecurringDots != oldValue else { return }
            settingsStore.set(hideRecurringDots, for: .hideRecurringDots)
        }
    }

    /// The reader's Hijri day offset (−2…+2). Held here as well as in the store so that views
    /// reading a date depend on it and redraw when Settings changes it; the services read the
    /// store themselves, live.
    private(set) var dayOffset: Int

    var weekStart: WeekStart {
        didSet {
            guard weekStart != oldValue else { return }
            settingsStore.set(weekStart.rawValue, for: .calendarWeekStart)
        }
    }

    @ObservationIgnored private let calendar: any HijriCalendarServicing
    @ObservationIgnored private let resolver: ResolveOccasionDatesUseCase
    @ObservationIgnored private let moonUseCase: GetMoonInfoUseCase
    @ObservationIgnored private let hijriDates: any HijriDateServicing
    @ObservationIgnored private let settingsStore: any SettingsStore
    @ObservationIgnored private let coordinates: @MainActor () -> Coordinates
    @ObservationIgnored private let config: @MainActor () -> CalculationConfig
    @ObservationIgnored private let clock: any ClockService
    @ObservationIgnored private let gregorian: Calendar
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let onOffsetChange: @MainActor () -> Void

    init(
        calendar: any HijriCalendarServicing,
        occasions: ResolveOccasionDatesUseCase,
        moon: GetMoonInfoUseCase,
        hijriDates: any HijriDateServicing,
        settingsStore: any SettingsStore,
        coordinates: @escaping @MainActor () -> Coordinates,
        config: @escaping @MainActor () -> CalculationConfig,
        clock: any ClockService,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        onOffsetChange: @escaping @MainActor () -> Void = {}
    ) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone

        self.calendar = calendar
        self.resolver = occasions
        self.moonUseCase = moon
        self.hijriDates = hijriDates
        self.settingsStore = settingsStore
        self.coordinates = coordinates
        self.config = config
        self.clock = clock
        self.gregorian = gregorian
        self.locale = locale
        self.onOffsetChange = onOffsetChange
        self.months = calendar.supportedYears.flatMap { year in
            HijriMonth.allCases.map { HijriMonthKey(year: year, month: $0) }
        }

        let today = gregorian.startOfDay(for: clock.now)
        self.selectedDay = today
        self.visibleMonth = calendar.monthKey(containing: today)
        self.showGregorian = settingsStore.bool(for: .showGregorianInCalendar) ?? false
        self.hideRecurringDots = settingsStore.bool(for: .hideRecurringDots) ?? false
        self.dayOffset = HijriDayOffset.current(in: settingsStore)
        self.weekStart = settingsStore.string(for: .calendarWeekStart).flatMap(WeekStart.init(rawValue:)) ?? .locale
    }

    // MARK: Reading

    var today: Date { gregorian.startOfDay(for: clock.now) }

    var supportedYears: ClosedRange<Int> { calendar.supportedYears }

    var firstWeekday: Int { weekStart.firstWeekday(locale: locale) }

    /// The seven weekday numbers in the order the grid's columns run, 1 = Sunday.
    var columnWeekdays: [Int] { (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 } }

    /// A date that falls on the given weekday, for asking the formatter for its heading. Any week
    /// would do; 7 Jan 2024 is a Sunday.
    func referenceDate(forWeekday weekday: Int) -> Date {
        gregorian.date(from: DateComponents(year: 2024, month: 1, day: 6 + weekday)) ?? today
    }

    /// Registers a dependency on the offset, so whatever calls this redraws when it changes.
    private func trackOffset() { _ = dayOffset }

    /// Changes the offset, writing it only if it is a change, and tells whoever drew the old date.
    func setDayOffset(_ value: Int) {
        let clamped = HijriDayOffset.clamp(value)
        guard clamped != dayOffset else { return }
        settingsStore.set(Double(clamped), for: .hijriDayOffset)
        dayOffset = clamped
        onOffsetChange()
    }

    func grid(for key: HijriMonthKey) -> MonthGrid? {
        trackOffset()
        return calendar.monthGrid(for: key, firstWeekday: firstWeekday)
    }

    /// Every month the pager can show, oldest first. Built once: it is two thousand values and
    /// the pager reads it on every redraw.
    let months: [HijriMonthKey]

    var hemisphere: MoonHemisphere { MoonHemisphere(latitude: coordinates().latitude) }

    /// The Gregorian day-of-month, for the small number under a Hijri one.
    func gregorianDayNumber(_ day: Date) -> Int { gregorian.component(.day, from: day) }

    /// Whether the pager is on the month that holds today — the Today button is only needed when
    /// it is not.
    var isShowingCurrentMonth: Bool {
        visibleMonth == calendar.monthKey(containing: today)
    }

    /// The first and last civil days of a month, for the Gregorian span under its name.
    func gregorianSpan(of key: HijriMonthKey) -> (first: Date, last: Date)? {
        guard let grid = grid(for: key), let first = grid.days.first, let last = grid.days.last else { return nil }
        return (first.gregorian, last.gregorian)
    }

    var gregorianCalendar: Calendar { gregorian }

    func hijriDate(of day: Date) -> HijriDate {
        trackOffset()
        return hijriDates.hijriComponents(for: day)
    }

    func isToday(_ day: Date) -> Bool { gregorian.isDate(day, inSameDayAs: today) }

    func isSelected(_ day: Date) -> Bool { gregorian.isDate(day, inSameDayAs: selectedDay) }

    /// The markers for one month, keyed by the start of each civil day.
    func markers(in grid: MonthGrid) -> [Date: DayMarker] {
        trackOffset()
        var result: [Date: DayMarker] = [:]
        let days = Set(grid.days.map(\.gregorian))
        for occurrence in resolver(hijriYear: grid.year) {
            for day in occurrence.days where days.contains(day.gregorian) {
                if occurrence.occasion.isRecurring {
                    if hideRecurringDots { continue }
                    result[day.gregorian, default: DayMarker()].hasRecurring = true
                } else {
                    result[day.gregorian, default: DayMarker()].hasOccasion = true
                }
            }
        }
        return result
    }

    /// The occasions on a civil day, one-off ones first.
    func occasions(on day: Date) -> [IslamicOccasion] {
        trackOffset()
        let start = gregorian.startOfDay(for: day)
        let year = calendar.monthKey(containing: start).year
        let found = resolver(hijriYear: year).filter { occurrence in
            occurrence.days.contains { gregorian.isDate($0.gregorian, inSameDayAs: start) }
        }
        return found.map(\.occasion).sorted { !$0.isRecurring && $1.isRecurring }
    }

    /// The next one-off occasions from today, under way ones included.
    func upcoming(limit: Int) -> [OccasionOccurrence] {
        trackOffset()
        return GetUpcomingOccasionsUseCase(resolve: resolver, calendar: calendar, gregorian: gregorian)(
            from: today,
            limit: limit
        )
    }

    /// An occasion falling today (a range under way counts) — always — or else the next one, but
    /// only within `lookAheadDays`. Recurring fasts never appear: two a week would always win.
    func cardOccasion(lookAheadDays: Int) -> CardOccasion? {
        if let now = occasions(on: today).first(where: { !$0.isRecurring }) {
            return .today(now)
        }
        guard let next = upcoming(limit: 1).first else { return nil }
        let days = daysAway(to: next)
        return days <= lookAheadDays ? .upcoming(next.occasion, days: days) : nil
    }

    /// Every one-off occasion of a Hijri year, earliest first. Recurring ones are left out: the
    /// year list is for the dozen that happen once, not the weekly fasts.
    func occurrences(inYear year: Int) -> [OccasionOccurrence] {
        resolver(hijriYear: year).filter { !$0.occasion.isRecurring }
    }

    /// Whole civil days from today to the start of an occurrence — negative once it has begun.
    func daysAway(to occurrence: OccasionOccurrence) -> Int {
        gregorian.dateComponents([.day], from: today, to: occurrence.first.gregorian).day ?? 0
    }

    /// Whole civil days from today to a date.
    func daysFromToday(to date: Date) -> Int {
        gregorian.dateComponents([.day], from: today, to: gregorian.startOfDay(for: date)).day ?? 0
    }

    func day(byAdding days: Int, to day: Date) -> Date {
        gregorian.date(byAdding: .day, value: days, to: day) ?? day
    }

    func moon(on day: Date) -> MoonInfo {
        moonUseCase(on: day, coordinates: coordinates(), config: config())
    }

    // MARK: Moving

    func select(_ day: Date) {
        selectedDay = gregorian.startOfDay(for: day)
    }

    /// Selects a day and brings its month into view — what a route from outside asks for.
    func reveal(_ day: Date) {
        select(day)
        show(calendar.monthKey(containing: selectedDay))
    }

    func show(_ key: HijriMonthKey) {
        guard supportedYears.contains(key.year) else { return }
        visibleMonth = key
    }

    func step(by months: Int) {
        var key = visibleMonth
        for _ in 0..<abs(months) {
            key = months > 0 ? key.next : key.previous
        }
        show(key)
    }

    func goToToday() {
        reveal(today)
    }
}
