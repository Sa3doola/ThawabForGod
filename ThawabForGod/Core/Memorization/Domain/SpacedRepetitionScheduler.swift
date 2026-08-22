//
//  SpacedRepetitionScheduler.swift
//  ThawabForGod
//

import Foundation

/// SM-2, as a pure function of a state and a grade.
///
/// **Active recall at increasing intervals**, which is the one thing the evidence on memorization
/// is unambiguous about and the reason the app schedules reviews rather than simply listing what
/// the reader chose. SuperMemo 2 is the algorithm the plan names; it is forty years old, it is
/// four lines of arithmetic, and every modern scheduler is a refinement of it.
///
/// Nothing here stores anything or knows what an item is. It takes a `MemorizationState`, an
/// answer and a date, and returns the next state — which is what makes the whole of the
/// scheduling logic testable without a database, a clock or a screen.
///
/// ## The algorithm
///
/// On every answer, the item's easiness moves by `0.1 - (5 - q)(0.08 + (5 - q) × 0.02)`, floored
/// at 1.3. Then:
///
/// - **Not recalled** (`.again`): the repetition count goes back to zero and the interval to one
///   day. The easiness change still applies — a lapse is evidence about the item, and forgetting
///   it should make it come back more often for good, not just tomorrow.
/// - **Recalled**: the repetition count goes up, and the interval becomes 1 day, then 6, then the
///   previous interval multiplied by the easiness. Those first two are constants in the original
///   paper rather than anything derived, and they are left as they are.
///
/// ## Days, not seconds
///
/// Intervals are whole days and due dates are the *start* of a day, so an item due "in one day"
/// is due tomorrow morning rather than twenty-four hours after it was answered. A reader
/// reviewing at ten at night and again at eight the next morning should find their deck waiting,
/// not ten hours short of ready.
///
/// **The calendar is built here rather than taken from `Calendar.current`.** A device set to the
/// Islamic calendar returns Hijri components from the current one, and day arithmetic done
/// through it would drift against the Gregorian dates every store in this app writes — the same
/// trap `PrayerTimeEngine` documents. The time zone *is* the user's, because when their day rolls
/// over is exactly the thing this has to get right.
nonisolated struct SpacedRepetitionScheduler: Sendable {

    /// The calendar day arithmetic is done in. Gregorian, in the user's time zone.
    private let calendar: Calendar

    init(timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// The day `date` falls in, which is what a due date always is.
    func day(of date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// A brand-new item, due today.
    func newState(on date: Date) -> MemorizationState {
        .new(on: day(of: date))
    }

    /// The state an item is in after being answered.
    ///
    /// - Parameters:
    ///   - state: where the item stood before this answer.
    ///   - grade: how the reader says it went.
    ///   - date: when they answered. Only the day of it is used.
    func next(
        _ state: MemorizationState,
        grade: ReviewGrade,
        on date: Date
    ) -> MemorizationState {
        let today = day(of: date)
        let easiness = adjusted(state.easiness, for: grade)

        let repetition = grade.isRecalled ? state.repetition + 1 : 0
        let interval = interval(after: repetition, previous: state.intervalInDays, easiness: easiness)

        return MemorizationState(
            easiness: easiness,
            repetition: repetition,
            intervalInDays: interval,
            // `byAdding:` rather than arithmetic on the interval in seconds, so a review across a
            // daylight-saving boundary still lands on the right morning.
            dueOn: calendar.date(byAdding: .day, value: interval, to: today) ?? today,
            lastReviewedOn: today
        )
    }

    /// SM-2's easiness update, floored at 1.3.
    ///
    /// Applied on every answer, including a failed one — `.good` happens to leave it unchanged,
    /// which falls out of the formula rather than being a special case.
    private func adjusted(_ easiness: Double, for grade: ReviewGrade) -> Double {
        let shortfall = Double(5 - grade.quality)
        let change = 0.1 - shortfall * (0.08 + shortfall * 0.02)

        return max(MemorizationState.minimumEasiness, easiness + change)
    }

    /// How many days until the item comes back.
    ///
    /// The 1 and the 6 are the original paper's constants for the first two successful
    /// repetitions, not values derived from anything here. After those, the interval is the last
    /// one multiplied by the item's easiness — which is what makes an easy item recede and a hard
    /// one stay close.
    private func interval(after repetition: Int, previous: Int, easiness: Double) -> Int {
        switch repetition {
        // A lapse. One day, so the item is the first thing tomorrow rather than gone for a week.
        case 0: 1
        case 1: 1
        case 2: 6
        // `max(1, …)` because a previous interval of 0 — an item failed and re-answered on the
        // same day — would otherwise multiply out to 0 and schedule it forever in the past.
        default: max(1, Int((Double(previous) * easiness).rounded()))
        }
    }
}
