//
//  QuranPagingTests.swift
//  ThawabForGodUITests
//
//  M8-B3: pages change by swipe and keyboard only. A tap on a word, the first or the last of its
//  line, selects its ayah and never turns the page. Full data only (Mushaf pages).
//
//  Identifiers relied on: `quran.panel.close` (column) or `quran.panel.done` (sheet),
//  `quran.reader.library`, `quran.reader.modeToggle`. Pages are read from the footer text.
//  An iPad is forced to landscape through XCUIDevice before launch; in a spread the pager shows
//  two pages and a turn moves two.
//

import XCTest

@MainActor
final class QuranPagingTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func setLandscapeOnPad() {
        #if os(iOS)
        if TestPlatform.isPad { XCUIDevice.shared.orientation = .landscapeLeft }
        #endif
    }

    private func launch(page: Int) throws -> XCUIApplication {
        setLandscapeOnPad()
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "\(page)"])
        try requireMushafPages(app)
        XCTAssertTrue(waitForOnScreenFooter(in: app, timeout: 15), "a page is on screen")
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 10), "ayahs are on the page")
        return app
    }

    // MARK: Taps never turn

    private func assertWordTapsNeverTurn(page: Int) throws {
        let app = try launch(page: page)
        let start = onScreenPageNumbers(in: app)
        XCTAssertTrue(start.contains(page), "launched on page \(page): \(start)")

        let ayahs = ayahsInBody(of: app, count: 3)
        XCTAssertFalse(ayahs.isEmpty, "page \(page) has ayahs in its body")
        // Labels, not elements: the panel can re-lay the page out between taps.
        let labels = ayahs.map(\.label)
        for label in labels {
            for edge in [WordEdge.first, .last] {
                let candidates = app.ayahElements.matching(NSPredicate(format: "label == %@", label))
                var target: XCUIElement?
                for index in 0..<candidates.count where isOnScreen(candidates.element(boundBy: index), in: app) {
                    target = candidates.element(boundBy: index)
                    break
                }
                let ayah = try XCTUnwrap(target, "'\(label)' is on screen")
                tapWord(of: ayah, edge: edge, in: app)

                dismissAyahPanel(in: app, opened: "page \(page), \(edge) word of '\(label)': the ayah panel opened")
                XCTAssertTrue(waitForPages(start, in: app), "page \(page), \(edge) word of '\(label)': the page did not change from \(start)")
            }
        }
    }

    func testWordTapsNeverTurnOnPage1() throws { try assertWordTapsNeverTurn(page: 1) }
    func testWordTapsNeverTurnOnPage2() throws { try assertWordTapsNeverTurn(page: 2) }
    func testWordTapsNeverTurnOnPage50() throws { try assertWordTapsNeverTurn(page: 50) }
    func testWordTapsNeverTurnOnPage604() throws { try assertWordTapsNeverTurn(page: 604) }

    // MARK: Swipes

    /// Swipe right is the next page, swipe left the previous; each lands on exactly the adjacent
    /// unit (n +- 1, or +- 2 in a spread), and nothing moves past either end.
    func testSwipesTurnExactlyOnePage() throws {
        let app = try launch(page: 50)
        let start = onScreenPageNumbers(in: app)
        let step = start.count
        let first = try XCTUnwrap(start.first)

        turnPage(next: true, in: app)
        XCTAssertTrue(waitForPages(start.map { $0 + step }, in: app), "swipe right: next page, from \(start)")
        turnPage(next: false, in: app)
        XCTAssertTrue(waitForPages(start, in: app), "swipe left: back to \(start)")
        turnPage(next: false, in: app)
        XCTAssertTrue(waitForPages(start.map { $0 - step }, in: app), "swipe left again: previous, \(first - step)")
    }

    func testSwipeBackStopsAtPage1() throws {
        let app = try launch(page: 2)
        // A single page steps 2 -> 1; a spread shows 1 and 2 together and is already the first unit.
        if onScreenPageNumbers(in: app).count == 1 {
            turnPage(next: false, in: app)
            XCTAssertTrue(waitForPages([1], in: app), "from 2 the previous page is 1")
        }
        let atStart = onScreenPageNumbers(in: app)
        XCTAssertEqual(atStart.first, 1)
        turnPage(next: false, in: app)
        // Absence of a change can only be waited for.
        XCTAssertFalse(waitForFooterToChange(from: onScreenFooterText(in: app) ?? "", in: app, timeout: 2), "nothing before page 1")
        XCTAssertEqual(onScreenPageNumbers(in: app), atStart, "still on the first page")
    }

    func testSwipeForwardStopsAtPage604() throws {
        let app = try launch(page: 604)
        let start = onScreenPageNumbers(in: app)
        XCTAssertEqual(start.last, 604)
        turnPage(next: true, in: app)
        XCTAssertFalse(waitForFooterToChange(from: onScreenFooterText(in: app) ?? "", in: app, timeout: 2), "nothing after page 604")
        XCTAssertEqual(onScreenPageNumbers(in: app), start, "still on the last page")
    }

    /// The old failure: a turn from page 2 landed on 604. One swipe each way must be n + 1 and back.
    func testTurnFromPage2NeverJumpsToTheEnd() throws {
        let app = try launch(page: 2)
        let start = onScreenPageNumbers(in: app)
        XCTAssertTrue(turnOnePage(in: app), "page 2 turns to the next unit and not to the last page")
        XCTAssertNotEqual(onScreenPageNumbers(in: app).last, 604)
        XCTAssertGreaterThan(try XCTUnwrap(onScreenPageNumbers(in: app).first), try XCTUnwrap(start.first))
    }

    // MARK: Keyboard

    /// iPad with a keyboard and the Mac: Left arrow is the next page, Right arrow the previous.
    private func assertArrowKeys(from page: Int) throws {
        try XCTSkipIf(TestPlatform.isPhone, "arrow keys need a keyboard: iPad and Mac")
        let app = try launch(page: page)
        let start = onScreenPageNumbers(in: app)
        let step = start.count

        if start.last != 604 {
            app.typeKey(.leftArrow, modifierFlags: [])
            XCTAssertTrue(waitForPages(start.map { $0 + step }, in: app), "left arrow from \(start): the next page, not the last")
            app.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertTrue(waitForPages(start, in: app), "right arrow: back to \(start)")
        } else {
            app.typeKey(.leftArrow, modifierFlags: [])
            XCTAssertFalse(waitForFooterToChange(from: onScreenFooterText(in: app) ?? "", in: app, timeout: 2), "no next page after 604")
        }
        if start.first != 1 {
            app.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertTrue(waitForPages(start.map { $0 - step }, in: app), "right arrow from \(start): the previous page")
        } else {
            app.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertFalse(waitForFooterToChange(from: onScreenFooterText(in: app) ?? "", in: app, timeout: 2), "no previous page before 1")
        }
    }

    func testArrowKeysFromPage1() throws { try assertArrowKeys(from: 1) }
    func testArrowKeysFromPage2() throws { try assertArrowKeys(from: 2) }
    func testArrowKeysFromPage50() throws { try assertArrowKeys(from: 50) }
    func testArrowKeysFromPage604() throws { try assertArrowKeys(from: 604) }
}
