//
//  QuranLibraryTests.swift
//  ThawabForGodUITests
//
//  M5.2: the Library's structure and its four indexes. The field's flows are in
//  `QuranLibraryGoToTests`, surah info in `QuranSurahInfoTests`.
//
//  Launches are `-quranLibrary <tab>` (the Library in front, no reader pushed). A flow that needs
//  Mushaf pages skips itself where the Page tab is absent; the public-build flows add
//  `-quranData public`, which swaps the database only.
//

import XCTest

@MainActor
final class QuranLibraryTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Both data modes. The Library is the Quran tab's root: the field, the picker and the list are
    /// there, the reader's own Library button is not, and nothing is offered that has not happened
    /// (no Continue reading row, no error, no Go or Clear on an empty field).
    func testLibraryIsTheRoot() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah)
        waitForLibrary(app)

        XCTAssertTrue(app.libraryQuery.exists, "the go-to field")
        XCTAssertTrue(app.libraryHint.exists, "the example line")
        XCTAssertFalse(app.libraryError.exists)
        XCTAssertFalse(app.libraryGo.exists, "Go appears with text")
        XCTAssertFalse(app.libraryClear.exists, "Clear appears with text")
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10), "the surah list")
        XCTAssertFalse(app.readerLibraryButton.exists, "the reader is not in front")
        XCTAssertFalse(app.libraryContinue.exists, "nothing to continue on a fresh launch")
        XCTAssertGreaterThanOrEqual(app.libraryTabCount, 3)
    }

    /// Forced public data. Three tabs and no Page tab, even when the machine has the full data: no
    /// Library row carries a page, the field never offers one, and `-quranLibrary page` falls back
    /// to Surah.
    func testPublicBuildShowsThreeTabs() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.page, ["-quranData", "public"])
        waitForLibrary(app)

        XCTAssertEqual(app.libraryTabCount, 3, "Surah, Juz, Hizb")
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10), "Surah is selected (Page was requested)")
        XCTAssertFalse(app.pageCell(1).exists, "no page grid")
        XCTAssertFalse(app.libraryQuery.placeholderValue?.contains("Page") ?? false, "the placeholder offers no page")
        XCTAssertFalse(app.libraryHint.label.contains("Page"), "the example line offers no page")

        for tab in [LibraryTab.surah, .juz, .hizb] {
            app.selectLibraryTab(tab)
            let anchor = tab == .surah ? app.surahRow(1) : (tab == .juz ? app.juzRow(1) : app.hizbRow(1))
            XCTAssertTrue(anchor.waitForExistence(timeout: 10), "the \(tab.rawValue) index")
            XCTAssertEqual(app.libraryRowLabels(containing: "Page"), 0, "no row on the \(tab.rawValue) tab names a page")
        }
    }

    /// Full data. Four tabs; `-quranLibrary page` opens the grid; the other tabs still work.
    func testFullBuildShowsFourTabsAndThePageGrid() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.page)
        try requireLibraryPages(app)

        XCTAssertEqual(app.libraryTabCount, 4)
        XCTAssertTrue(app.pageCell(1).waitForExistence(timeout: 10), "the page grid is showing")
        XCTAssertFalse(app.surahRow(1).exists)
        app.selectLibraryTab(.surah)
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10), "back to Surah")
        app.selectLibraryTab(.page)
        XCTAssertTrue(app.pageCell(1).waitForExistence(timeout: 10), "and to Page again")
    }

    /// Both modes. Juz 30 opens the reader at the juz's start: with pages, on the page its row names;
    /// without, at the ayah its row names, under the surah's name.
    func testJuzRowOpensTheReader() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.juz, ["-quranMode", "mushaf"])
        waitForLibrary(app)
        let hasPages = app.libraryHasPages

        scrollToLibraryRow(prefix: "juz", 30, in: app)
        let row = app.juzRow(30)
        let place = try XCTUnwrap(startPlace(ofRow: row), "the row's label is 'title, name s:a': \(row.label)")
        if hasPages { XCTAssertNotNil(place.page, "a full build's row names its page: \(row.label)") }
        row.tapOrClick()

        waitForReader(app)
        if hasPages {
            let page = try XCTUnwrap(place.page)
            XCTAssertTrue(waitForOnScreenFooter(in: app), "a page footer")
            XCTAssertTrue(onScreenFooterText(in: app)?.hasSuffix("Page \(page)") ?? false, "the footer says Page \(page)")
        } else {
            XCTAssertNil(onScreenFooterText(in: app), "no page footer without pages")
            XCTAssertTrue(waitForText(place.name, in: app), "the reader shows \(place.name)")
            XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: place.ayah), in: app, timeout: 15), "the start ayah is on screen")
        }
    }

    /// Both modes (separated, which both builds have). Hizb 2's row opens the reader; back in the
    /// Library, disclosing it and tapping its first later quarter opens that quarter's own ayah.
    func testHizbAndItsQuarterOpenTheReader() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.hizb, ["-quranMode", "separated"])
        waitForLibrary(app)

        XCTAssertTrue(app.hizbRow(2).waitForExistence(timeout: 10))
        app.hizbRow(2).tapOrClick()
        waitForReader(app)
        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)

        // Hizb 2 owns rubs 5...8; 6 is its first later quarter.
        XCTAssertTrue(app.hizbRow(2).waitForExistence(timeout: 10))
        app.discloseHizb(2)
        XCTAssertTrue(app.quarterRow(6).waitForExistence(timeout: 5), "disclosing hizb 2 shows its quarters")
        let quarter = app.quarterRow(6)
        let place = try XCTUnwrap(startPlace(ofRow: quarter), "the quarter's label: \(quarter.label)")
        quarter.tapOrClick()

        waitForReader(app)
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: place.ayah), in: app, timeout: 15), "the quarter's ayah \(place.surah):\(place.ayah) is on screen")
    }

    /// Full data. Page cell 50 opens the Mushaf at page 50; back in the Library the Page tab is
    /// still showing, and cell 50 is selected and on screen.
    func testPageCellOpensThePageAndIsCurrentOnReturn() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.page, ["-quranMode", "mushaf"])
        try requireLibraryPages(app)

        scrollToLibraryRow(prefix: "page", 50, in: app, maxScrolls: 40)
        app.pageCell(50).tapOrClick()
        waitForReader(app)
        XCTAssertTrue(waitForOnScreenFooter(in: app), "a page footer")
        XCTAssertTrue(onScreenFooterText(in: app)?.hasSuffix("Page 50") ?? false, "the footer says Page 50")

        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        XCTAssertTrue(app.pageCell(50).waitForExistence(timeout: 10), "the Page tab is still selected")
        XCTAssertTrue(waitUntilSelected(app.pageCell(50)), "cell 50 is the current page")
        XCTAssertTrue(waitUntilOnScreen(app.pageCell(50), in: app), "and the grid scrolled it into view")
    }

    /// Both modes. Not there on a fresh launch; open surah 18, move, tap Library: the row is there
    /// and names surah 18; tapping it returns to the reader where it was.
    func testContinueReadingReturnsToTheSamePlace() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranMode", "mushaf"])
        waitForLibrary(app)
        XCTAssertFalse(app.libraryContinue.exists, "nothing to continue yet")

        scrollToSurahRow(18, in: app)
        let name = surahName(ofRow: app.surahRow(18))
        app.surahRow(18).tapOrClick()
        waitForReader(app)
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))

        // Where the reader is: the footer in Mushaf mode, the ayahs on screen in separated mode.
        let hasFooter = waitForOnScreenFooter(in: app, timeout: 5)
        if hasFooter { XCTAssertTrue(turnOnePage(in: app), "move off the first page") }
        let footerBefore = onScreenFooterText(in: app)
        let ayahsBefore = onScreenAyahLabels(in: app)
        XCTAssertFalse(ayahsBefore.isEmpty, "something is on screen")

        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        XCTAssertTrue(app.libraryContinue.waitForExistence(timeout: 10), "Continue reading is offered")
        XCTAssertTrue(app.libraryContinue.label.contains(name), "it names \(name): \(app.libraryContinue.label)")

        // Narrowing the surah list hides the bar; clearing the field brings it back.
        app.typeInLibraryField("kahf")
        XCTAssertTrue(app.libraryContinue.waitForNonExistence(timeout: 10), "hidden while the field filters")
        app.libraryClear.tapOrClick()
        XCTAssertTrue(app.libraryContinue.waitForExistence(timeout: 10), "back once the field is cleared")

        app.libraryContinue.tapOrClick()
        waitForReader(app)
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
        if let footerBefore {
            XCTAssertTrue(waitForOnScreenFooter(in: app))
            XCTAssertEqual(onScreenFooterText(in: app), footerBefore, "the same page")
        } else {
            let before = ayahsBefore
            let predicate = NSPredicate { [self] _, _ in !onScreenAyahLabels(in: app).isDisjoint(with: before) }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, "an ayah that was on screen is on screen again")
        }
    }
}
