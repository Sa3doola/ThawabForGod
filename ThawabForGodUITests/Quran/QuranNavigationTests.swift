//
//  QuranNavigationTests.swift
//  ThawabForGodUITests
//
//  M5.1: the Library (the tab's root) and the reader, in both data modes.
//

import XCTest

@MainActor
final class QuranNavigationTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Both modes. Library button -> the list; a surah row -> the reader at that surah; Library ->
    /// the list again. The surah's name is read off the row's own label (number, name, Arabic name,
    /// joined by ", "), not typed in; the reader must show it somewhere (Mushaf header, ayah
    /// elements, or the bar title).
    func testLibraryToReaderAndBack() throws {
        let app = XCUIApplication()
        // A target is needed to get past onboarding; the reader is then popped.
        app.launchQuran(["-quranSurah", "1"])
        waitForReader(app)

        app.readerLibraryButton.tapOrClick()
        XCTAssertTrue(app.libraryList.waitForExistence(timeout: 10), "the Library")
        XCTAssertFalse(app.readerLibraryButton.exists, "the reader is gone")
        captureScreenshot(app, screen: "library", theme: "app")

        let row = app.surahRow(18)
        scrollToSurahRow(18, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the row of surah 18")
        let parts = row.label.components(separatedBy: ", ")
        let name = parts.count >= 2 ? parts[1] : row.label
        XCTAssertFalse(name.isEmpty)
        row.tapOrClick()

        waitForReader(app)
        XCTAssertTrue(app.libraryList.waitForNonExistence(timeout: 10), "the Library is covered by the reader")
        let shown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", name, name)).firstMatch
        XCTAssertTrue(shown.waitForExistence(timeout: 15), "the reader shows surah \(name)")

        app.readerLibraryButton.tapOrClick()
        XCTAssertTrue(app.libraryList.waitForExistence(timeout: 10), "Library returns to the list")
    }

    /// Both modes (separated mode, which both builds have). Reopening the surah that is already open
    /// goes to its top: launch at 2:40, Library, surah 2's row; ayah 1 is on screen and ayah 40 is not.
    func testReopeningTheOpenSurahGoesToItsTop() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "40"])
        waitForReader(app)
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 40), in: app, timeout: 15), "the launch opens at ayah 40")

        app.readerLibraryButton.tapOrClick()
        XCTAssertTrue(app.libraryList.waitForExistence(timeout: 10))
        scrollToSurahRow(2, in: app)
        app.surahRow(2).tapOrClick()

        waitForReader(app)
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 1), in: app, timeout: 15), "the surah opens at its first ayah")
        XCTAssertFalse(isOnScreen(app.ayahElement(verse: 40), in: app), "ayah 40 is below the fold")
    }

    /// Both modes, tab bar only (iPhone / compact width; skipped where the arrangement is a
    /// sidebar). Another tab and back: the reader is still open, on the same place.
    func testAnotherTabAndBackKeepsTheReader() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)
        try XCTSkipUnless(app.appTabBar.waitForExistence(timeout: 5), "No tab bar here (sidebar arrangement or macOS)")

        // What marks the place, in whichever mode: the footer's text, else the first ayah's label.
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
        func place() -> String {
            onScreenFooterText(in: app) ?? app.ayahElements.firstMatch.label
        }
        // Mushaf mode has a footer on screen; separated mode has none anywhere.
        XCTAssertTrue(waitForOnScreenFooter(in: app) || !app.anyPageFooter.exists, "the place can be read")
        let before = place()

        let quranTab = app.appTabBar.buttons.matching(NSPredicate(format: "isSelected == true")).firstMatch
        XCTAssertTrue(quranTab.exists)
        let quranTabLabel = quranTab.label
        let other = app.appTabBar.buttons.matching(NSPredicate(format: "isSelected == false")).firstMatch
        XCTAssertTrue(other.exists)
        let otherLabel = other.label
        selectTab(app.appTabBar.buttons[otherLabel])
        XCTAssertFalse(app.appTabBar.buttons[quranTabLabel].isSelected, "another tab is selected")

        selectTab(app.appTabBar.buttons[quranTabLabel])
        waitForReader(app)
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
        if app.anyPageFooter.exists { _ = waitForOnScreenFooter(in: app) }
        XCTAssertEqual(place(), before, "the reader is where it was left")
        XCTAssertFalse(app.libraryList.exists)
    }
}
