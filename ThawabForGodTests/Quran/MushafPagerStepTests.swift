//
//  MushafPagerStepTests.swift
//  ThawabForGodTests
//

import Testing
@testable import ThawabForGod

/// The Mushaf pager's page-step maths and its stray-report rule (M8-B3). Pure: no view, no state.
/// The reader's `turn`/`canTurn` are checked against the same rules in `MushafReadingStateTurnTests`.
struct MushafPagerStepTests {
    private static let pages = 1...604

    private func target(_ turn: MushafPageTurn, from page: Int, pageCount: Int) -> Int? {
        MushafPagerStep.target(of: turn, from: page, pageCount: pageCount, pages: Self.pages)
    }

    // MARK: Turns on a single page

    @Test func singlePageTurnsOnePage() {
        #expect(target(.next, from: 1, pageCount: 1) == 2)
        #expect(target(.next, from: 2, pageCount: 1) == 3)
        #expect(target(.previous, from: 2, pageCount: 1) == 1)
        #expect(target(.next, from: 50, pageCount: 1) == 51)
        #expect(target(.previous, from: 50, pageCount: 1) == 49)
        #expect(target(.previous, from: 604, pageCount: 1) == 603)
    }

    @Test func singlePageHasNoTurnPastEitherEnd() {
        #expect(target(.previous, from: 1, pageCount: 1) == nil)
        #expect(target(.next, from: 604, pageCount: 1) == nil)
    }

    // MARK: Turns in a spread

    @Test func spreadTurnsTwoPagesFromTheOddPage() {
        #expect(target(.next, from: 1, pageCount: 2) == 3)
        #expect(target(.next, from: 50, pageCount: 2) == 51)
        #expect(target(.previous, from: 50, pageCount: 2) == 47)
        #expect(target(.previous, from: 604, pageCount: 2) == 601)
    }

    @Test func spreadStepsFromTheSameUnitWhicheverPageOfItIsOn() {
        // Page 2 is the spread 1–2: the turn starts from the odd page 1.
        #expect(target(.next, from: 2, pageCount: 2) == 3)
        #expect(target(.previous, from: 2, pageCount: 2) == nil)
    }

    @Test func spreadHasNoTurnPastEitherEnd() {
        #expect(target(.previous, from: 1, pageCount: 2) == nil)
        #expect(target(.next, from: 604, pageCount: 2) == nil)
    }

    // MARK: Accepting a report from the scroll view

    @Test func aNeighbouringUnitIsAccepted() {
        #expect(MushafPagerStep.accepts(reported: 2, page: 1, pageCount: 1, jumpTarget: nil))
        #expect(MushafPagerStep.accepts(reported: 3, page: 1, pageCount: 2, jumpTarget: nil))
    }

    @Test func aFarReportWithoutAJumpIsStray() {
        // Content offset 0 in the RTL scroll view is the last unit, so a mirrored landing reports 604.
        #expect(!MushafPagerStep.accepts(reported: 604, page: 1, pageCount: 1, jumpTarget: nil))
        #expect(!MushafPagerStep.accepts(reported: 1, page: 604, pageCount: 1, jumpTarget: nil))
        #expect(!MushafPagerStep.accepts(reported: 603, page: 1, pageCount: 2, jumpTarget: nil))
    }

    @Test func thePendingJumpTargetIsAccepted() {
        #expect(MushafPagerStep.accepts(reported: 300, page: 1, pageCount: 1, jumpTarget: 300))
    }

    @Test func aPendingJumpRejectsAnythingElse() {
        #expect(!MushafPagerStep.accepts(reported: 604, page: 1, pageCount: 1, jumpTarget: 300))
    }
}

/// `MushafReadingState.turn` and `canTurn`, which delegate to `MushafPagerStep.target`.
@MainActor
struct MushafReadingStateTurnTests {
    @Test func turningPastTheLastPageDoesNothing() {
        let state = MushafReadingState(page: 604, pages: 1...604)
        var reports: [Int] = []
        state.onPageChange = { reports.append($0) }

        state.turn(.next)

        #expect(state.page == 604)
        #expect(!state.canTurn(.next))
        #expect(reports.isEmpty)
    }

    @Test func turningBeforeTheFirstPageDoesNothing() {
        let state = MushafReadingState(page: 1, pages: 1...604)
        var reports: [Int] = []
        state.onPageChange = { reports.append($0) }

        state.turn(.previous)

        #expect(state.page == 1)
        #expect(!state.canTurn(.previous))
        #expect(reports.isEmpty)
    }

    @Test func eachTurnReportsExactlyOnce() {
        let state = MushafReadingState(page: 1, pages: 1...604)
        var reports: [Int] = []
        state.onPageChange = { reports.append($0) }

        state.turn(.next)
        #expect(state.page == 2)
        #expect(reports == [2])

        state.turn(.previous)
        #expect(state.page == 1)
        #expect(reports == [2, 1])
    }

    @Test func aSpreadTurnMovesTwoPagesAndReportsOnce() {
        let state = MushafReadingState(page: 50, pages: 1...604)
        state.visiblePageCount = 2
        var reports: [Int] = []
        state.onPageChange = { reports.append($0) }

        state.turn(.next)
        #expect(state.page == 51)
        #expect(reports == [51])

        state.turn(.previous)
        #expect(state.page == 49)
        #expect(reports == [51, 49])
    }

    @Test func aSpreadOnTheLastUnitCannotTurnNext() {
        let state = MushafReadingState(page: 604, pages: 1...604)
        state.visiblePageCount = 2

        #expect(state.page == 604)
        #expect(!state.canTurn(.next))
        #expect(state.canTurn(.previous))
    }

    @Test func canTurnAgreesWithTheEnds() {
        let first = MushafReadingState(page: 1, pages: 1...604)
        #expect(!first.canTurn(.previous))
        #expect(first.canTurn(.next))

        let last = MushafReadingState(page: 604, pages: 1...604)
        #expect(last.canTurn(.previous))
        #expect(!last.canTurn(.next))
    }
}
