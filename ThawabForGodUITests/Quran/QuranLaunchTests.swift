//
//  QuranLaunchTests.swift
//  ThawabForGodUITests
//
//  M5.1: scripted launches land on the right screen, in both data modes.
//

import XCTest

@MainActor
final class QuranLaunchTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Full data. `-quranMode mushaf -quranPage 50`: the page footer, the Library button and the
    /// mode toggle. Skips in a public clone (no toggle).
    func testLaunchOpensMushafPage() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)

        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15), "the footer of page 50")
        XCTAssertTrue(app.readerLibraryButton.exists)
        XCTAssertTrue(app.hasDisplayModeControl, "the mode toggle, or the More menu that holds it at compact width")
        XCTAssertFalse(app.libraryList.exists, "the reader, not the Library, is in front")
    }

    /// Both data modes. `-quranMode separated -quranSurah 2 -quranAyah 255`: that ayah's row, and the
    /// surah's name in the bar. The name is read off the row's own label ("<name>, ayah 255"), so no
    /// label is copied into the test.
    func testLaunchOpensSeparatedAyah() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255"])
        waitForReader(app)

        let row = app.ayahElement(verse: 255)
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the row of ayah 255")
        XCTAssertFalse(app.anyPageFooter.exists, "separated mode has no page footer")

        let suffix = ", ayah 255"
        XCTAssertTrue(row.label.hasSuffix(suffix))
        let surahName = String(row.label.dropLast(suffix.count))
        XCTAssertFalse(surahName.isEmpty)
        let title = app.titleText(surahName)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the surah's name is the bar's title")
    }

    /// Forced public database (`-quranData public`), whatever is bundled: asked for Mushaf mode at
    /// page 50, the reader still opens, with no mode toggle, no page footer, and ayah rows.
    func testPublicDatabaseHasNoMushafMode() {
        let app = XCUIApplication()
        app.launchQuran(["-quranData", "public", "-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)

        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15), "ayah rows are shown")
        XCTAssertFalse(app.hasDisplayModeControl, "no mode toggle (or More menu) without Mushaf pages")
        XCTAssertFalse(app.anyPageFooter.exists, "no page footer without Mushaf pages")
    }
}
