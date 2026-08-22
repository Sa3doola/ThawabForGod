//
//  SpacedRepetitionSchedulerTests.swift
//  ThawabForGodTests
//

import Foundation
import Testing
@testable import ThawabForGod

/// SM-2, checked against the algorithm as published.
///
/// The whole of the scheduling logic is a pure function of a state and a grade, which is what
/// makes this suite possible without a store, a clock or a screen — and what makes it the right
/// place for the arithmetic to be pinned rather than discovered on device three weeks in.
struct SpacedRepetitionSchedulerTests {

    /// UTC, so the day boundaries in these tests are the ones written here rather than whichever
    /// zone the machine running them happens to be in.
    private let scheduler = SpacedRepetitionScheduler(timeZone: TimeZone(identifier: "UTC")!)

    private let today = Date(timeIntervalSince1970: 1_750_000_000)

    private func days(_ count: Int, after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(byAdding: .day, value: count, to: calendar.startOfDay(for: date))!
    }

    // MARK: A new item

    /// Due *today*, not tomorrow. The reader has just chosen to memorize it, and the one moment
    /// they certainly want to see it is now — SM-2 describes what happens after the first review,
    /// not before it.
    @Test func aNewItemIsDueImmediately() {
        let state = scheduler.newState(on: today)

        #expect(state.isNew)
        #expect(state.isDue(on: today))
        #expect(state.repetition == 0)
        #expect(state.easiness == MemorizationState.initialEasiness)
    }

    /// Due dates are the start of a day, so an item answered at ten at night is waiting at eight
    /// the next morning rather than ten hours short of ready.
    @Test func dueDatesAreWholeDays() {
        let evening = Date(timeIntervalSince1970: 1_750_000_000 + 23 * 3600)
        let state = scheduler.newState(on: evening)

        #expect(state.dueOn == scheduler.day(of: evening))
    }

    // MARK: The interval ladder

    /// The first two intervals are the original paper's constants — 1 day, then 6 — rather than
    /// anything derived. After that the interval is the last one times the easiness.
    @Test func recallingItThreeTimesWalksUpTheLadder() {
        var state = scheduler.newState(on: today)

        state = scheduler.next(state, grade: .good, on: today)
        #expect(state.repetition == 1)
        #expect(state.intervalInDays == 1)

        state = scheduler.next(state, grade: .good, on: today)
        #expect(state.repetition == 2)
        #expect(state.intervalInDays == 6)

        // 6 × 2.5 = 15. `.good` leaves the easiness at its starting value, which falls out of the
        // formula rather than being a special case.
        state = scheduler.next(state, grade: .good, on: today)
        #expect(state.repetition == 3)
        #expect(state.easiness == 2.5)
        #expect(state.intervalInDays == 15)
    }

    @Test func theDueDateIsTheIntervalAfterTheDayItWasAnswered() {
        var state = scheduler.newState(on: today)
        state = scheduler.next(state, grade: .good, on: today)
        state = scheduler.next(state, grade: .good, on: today)

        #expect(state.dueOn == days(6, after: today))
    }

    // MARK: Failing

    /// **A lapse starts the ladder over.** Repetition to zero and the interval to one day, so the
    /// item is the first thing tomorrow rather than gone for a fortnight.
    @Test func failingResetsTheLadder() {
        var state = scheduler.newState(on: today)
        state = scheduler.next(state, grade: .good, on: today)
        state = scheduler.next(state, grade: .good, on: today)
        state = scheduler.next(state, grade: .good, on: today)

        state = scheduler.next(state, grade: .again, on: today)

        #expect(state.repetition == 0)
        #expect(state.intervalInDays == 1)
        #expect(state.dueOn == days(1, after: today))
    }

    /// The easiness change still applies to a failure. Forgetting something is evidence about the
    /// item and should make it come back more often for good, not just tomorrow.
    @Test func failingAlsoMakesTheItemHarderForGood() {
        let state = scheduler.next(scheduler.newState(on: today), grade: .again, on: today)

        // 2.5 + (0.1 - 5 × (0.08 + 5 × 0.02)) = 2.5 - 0.8
        #expect(abs(state.easiness - 1.7) < 0.0001)
    }

    // MARK: Easiness

    /// The four answers and what each does to the factor. `good` is neutral, `easy` adds, and
    /// both failing answers subtract — which is the published formula and not a choice made here.
    @Test(arguments: [
        (ReviewGrade.again, -0.8),
        (ReviewGrade.hard, -0.14),
        (ReviewGrade.good, 0.0),
        (ReviewGrade.easy, 0.1)
    ])
    func eachGradeMovesTheEasinessByItsOwnAmount(grade: ReviewGrade, change: Double) {
        let state = scheduler.next(scheduler.newState(on: today), grade: grade, on: today)

        #expect(abs(state.easiness - (MemorizationState.initialEasiness + change)) < 0.0001)
    }

    /// **1.3 is the algorithm's floor, and it matters.** An item whose factor is allowed to
    /// collapse ends up scheduled every day forever, at which point the reader abandons the whole
    /// deck rather than the one item.
    @Test func theEasinessNeverFallsBelowTheFloor() {
        var state = scheduler.newState(on: today)

        for _ in 0..<20 {
            state = scheduler.next(state, grade: .again, on: today)
        }

        #expect(state.easiness == MemorizationState.minimumEasiness)
    }

    /// `hard` is a *pass*. It sits on SM-2's boundary at quality 3, so answering it does not throw
    /// away the reader's progress on an item they did in fact remember.
    @Test func answeringHardKeepsTheRepetitionCount() {
        var state = scheduler.newState(on: today)
        state = scheduler.next(state, grade: .good, on: today)

        state = scheduler.next(state, grade: .hard, on: today)

        #expect(state.repetition == 2)
        #expect(state.intervalInDays == 6)
    }

    // MARK: Being due

    /// An item missed on Tuesday is still due on Thursday. A queue that only offered today's
    /// would quietly drop everything skipped.
    @Test func anOverdueItemIsStillDue() {
        var state = scheduler.newState(on: today)
        state = scheduler.next(state, grade: .good, on: today)

        #expect(!state.isDue(on: today))
        #expect(state.isDue(on: days(1, after: today)))
        #expect(state.isDue(on: days(30, after: today)))
    }

    /// An item answered and failed on the same day has a previous interval of zero, which would
    /// otherwise multiply out to zero and schedule it forever in the past.
    @Test func anIntervalNeverCollapsesToZero() {
        var state = scheduler.newState(on: today)

        for _ in 0..<6 {
            state = scheduler.next(state, grade: .again, on: today)
            state = scheduler.next(state, grade: .hard, on: today)
        }

        #expect(state.intervalInDays >= 1)
        #expect(state.dueOn > scheduler.day(of: today))
    }
}
