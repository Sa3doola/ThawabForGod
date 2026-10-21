//
//  MoonDetailViewModel.swift
//  ThawabForGod
//

import Foundation
import Observation

/// The moon screen's state, for whichever day the calendar has selected.
///
/// It owns no day of its own. The calendar's selection is the one source, so jumping to a phase
/// here moves the calendar behind it and the two cannot disagree about which day is meant.
@Observable
@MainActor
final class MoonDetailViewModel {

    @ObservationIgnored private let calendar: HijriCalendarViewModel
    @ObservationIgnored private let strip: GetMoonPhaseStripUseCase
    @ObservationIgnored private let next: GetNextMoonEventsUseCase
    @ObservationIgnored private let clock: any ClockService

    init(
        calendar: HijriCalendarViewModel,
        strip: GetMoonPhaseStripUseCase,
        next: GetNextMoonEventsUseCase,
        clock: any ClockService
    ) {
        self.calendar = calendar
        self.strip = strip
        self.next = next
        self.clock = clock
    }

    var day: Date { calendar.selectedDay }

    var hemisphere: MoonHemisphere { calendar.hemisphere }

    /// The moon at Maghrib on the selected day.
    var info: MoonInfo { calendar.moon(on: day) }

    /// The eight phases of the lunar month the selected day is in.
    var phases: [MoonInfo] { strip(around: info.date) }

    /// The next new and full moon after now, not after the selected day: they answer "when", and
    /// the reader asking is asking from today.
    var events: GetNextMoonEventsUseCase.Events { next(after: clock.now) }

    func daysUntil(_ date: Date) -> Int { calendar.daysFromToday(to: date) }

    /// Selects the next civil day on which the moon is in `phase`.
    ///
    /// If the selected day is already in it, the answer is the *following* occurrence — the next
    /// day it begins — not the run the reader is standing in. Returns the day chosen, or `nil`
    /// if none turned up inside a lunar month and a bit.
    @discardableResult
    func jump(to phase: MoonPhase) -> Date? {
        var candidate = calendar.day(byAdding: 1, to: day)
        var inRun = info.phase == phase

        for _ in 0..<40 {
            let current = calendar.moon(on: candidate).phase
            if inRun {
                inRun = current == phase
            } else if current == phase {
                calendar.reveal(candidate)
                return candidate
            }
            candidate = calendar.day(byAdding: 1, to: candidate)
        }
        return nil
    }
}
