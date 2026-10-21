//
//  QuranModeSwitchTests.swift
//  ThawabForGodUITests
//
//  M5.1: the mode toggle, and the place it keeps. Full data only: both skip themselves when the
//  toggle does not exist once the reader has loaded.
//

import XCTest

@MainActor
final class QuranModeSwitchTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// The toggle goes Mushaf -> separated (footer gone, ayah rows shown) and back (footer returns).
    func testToggleSwitchesAndSwitchesBack() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))

        app.toggleDisplayMode()
        XCTAssertTrue(app.anyPageFooter.waitForNonExistence(timeout: 10), "separated mode has no footer")
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 10), "ayah rows")

        app.toggleDisplayMode()
        XCTAssertTrue(app.anyPageFooter.waitForExistence(timeout: 10), "the footer is back in Mushaf mode")
    }

    /// Full data. The switch keeps the *current* place inside one surah. Launch at page 201 (it does
    /// not begin a surah), turn one page so the current place differs from the launch place, then
    /// switch: separated mode must show an ayah of the new page, not one of the launch page, and not
    /// the surah's first ayah. (Switching at once would pass even if the list were built from the
    /// place the view last held.) Ayahs are read off the pages' own elements; one is picked from
    /// each side that the other side does not also expose, since an ayah can continue across a break.
    func testSwitchKeepsThePlaceInsideOneSurah() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "201"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(201), in: app, timeout: 15))
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 10))
        let launchLabels = onScreenAyahLabels(in: app)
        XCTAssertFalse(launchLabels.isEmpty, "ayahs are on screen on the launch page")

        XCTAssertTrue(turnOnePage(in: app), "the page turned: the footer changed")
        // The new page's ayahs: wait until the on-screen set no longer matches the launch page's.
        var turnedLabels = onScreenAyahLabels(in: app)
        let settled = NSPredicate { [self] _, _ in
            turnedLabels = onScreenAyahLabels(in: app)
            return !turnedLabels.isEmpty && !turnedLabels.isSubset(of: launchLabels)
        }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 10), .completed)

        let onlyLaunch = launchLabels.subtracting(turnedLabels).sorted()
        let onlyTurned = turnedLabels.subtracting(launchLabels).sorted()
        let launchOnly = try XCTUnwrap(onlyLaunch.first, "an ayah only the launch page exposed")
        let turnedOnly = try XCTUnwrap(onlyTurned.first, "an ayah only the new page exposed")

        // `turnOnePage` goes forward first and backward only if that changed nothing. Rows of the launch
        // page come *after* the new place only in the backward case, where they may legitimately show.
        let wentForward = isOnScreen(app.pageFooter(202), in: app)

        app.toggleDisplayMode()
        XCTAssertTrue(app.anyPageFooter.waitForNonExistence(timeout: 10))
        let row = app.buttons.matching(NSPredicate(format: "label == %@", turnedOnly)).firstMatch
        XCTAssertTrue(waitUntilOnScreen(row, in: app, timeout: 15), "separated shows '\(turnedOnly)', an ayah of the new page")
        let launchRow = app.buttons.matching(NSPredicate(format: "label == %@", launchOnly)).firstMatch
        if wentForward {
            XCTAssertFalse(isOnScreen(launchRow, in: app), "'\(launchOnly)', from the launch page, is not on screen")
        }
        XCTAssertFalse(isOnScreen(app.ayahElement(verse: 1), in: app), "the surah's first ayah is not what is on screen")
    }

    /// Page 50 -> separated: the first ayah in view is one that page showed. Separated at 2:255 ->
    /// Mushaf: the page that holds that ayah. Page and ayah are never typed in as expected values:
    /// the first is checked against the ayah elements the page itself exposed, the second against
    /// ayah 255's element on the page.
    func testSwitchKeepsThePlace() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 10))

        // Every ayah the page exposed (the pager may also hold a neighbour's: that only widens the set).
        let onPage = Set((0..<app.ayahElements.count).map { app.ayahElements.element(boundBy: $0).label })
        XCTAssertFalse(onPage.isEmpty)

        app.toggleDisplayMode()
        XCTAssertTrue(app.anyPageFooter.waitForNonExistence(timeout: 10))
        let first = app.ayahElements.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(onPage.contains(first.label), "separated opens at an ayah of page 50, got \(first.label)")

        // And the other way, from an ayah chosen by launch.
        app.terminate()
        app.launchQuran(["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255"])
        try requireMushafPages(app)
        XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 15))
        XCTAssertFalse(app.anyPageFooter.exists)

        app.toggleDisplayMode()
        XCTAssertTrue(app.anyPageFooter.waitForExistence(timeout: 10), "Mushaf mode shows a page")
        XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 10), "the page holds ayah 255")
    }
}
