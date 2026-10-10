//
//  QuranScreenshotTests.swift
//  ThawabForGodUITests
//
//  M5.1 screenshots, for eyes and not assertions (XCUITest cannot read a bar's colour). Each is
//  attached to the test and, with TEST_RUNNER_QURAN_SCREENSHOT_DIR set, written to
//  Screenshots/quran-migration/M5/M5.1/<device>-<screen>-<theme>.png (git-ignored). Run on an
//  iPhone SE, an iPhone 17 Pro, an iPad (regular width) and the Mac to cover the note's list.
//

import XCTest

@MainActor
final class QuranScreenshotTests: XCTestCase {
    private let themes = ["paper", "sepia", "dark"]

    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// The reader with its bars in each page theme, in each mode the build has.
    func testReaderBarsInEachTheme() throws {
        for theme in themes {
            let app = XCUIApplication()
            app.launchQuran(["-quranMode", "mushaf", "-quranTheme", theme, "-quranPage", "50"])
            waitForReader(app)
            XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
            if app.anyPageFooter.exists {
                XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))
                captureScreenshot(app, screen: "reader-mushaf", theme: theme)
            }
            app.terminate()

            app.launchQuran(["-quranMode", "separated", "-quranTheme", theme, "-quranSurah", "2", "-quranAyah", "255"])
            waitForReader(app)
            XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 15))
            captureScreenshot(app, screen: "reader-separated", theme: theme)
            app.terminate()
        }
    }

    /// The Home tab straight after a dark reader: the leak check. A tab bar only (iPhone).
    func testHomeTabAfterDarkReader() throws {
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranTheme", "dark", "-quranPage", "50"])
        waitForReader(app)
        try XCTSkipUnless(app.appTabBar.waitForExistence(timeout: 5), "No tab bar here (sidebar arrangement or macOS)")
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))

        let other = app.appTabBar.buttons.matching(NSPredicate(format: "isSelected == false")).firstMatch
        selectTab(app.appTabBar.buttons[other.label])
        XCTAssertTrue(app.readerLibraryButton.waitForNonExistence(timeout: 10), "the reader's bar is not on the other tab")
        captureScreenshot(app, screen: "home-after-reader", theme: "dark")
    }

    /// iPad in regular width: the reader in the detail column, sidebar open.
    func testIPadSidebar() throws {
        try XCTSkipUnless(TestPlatform.isPad, "iPad only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranTheme", "sepia", "-quranPage", "50"])
        waitForReader(app)
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
        captureScreenshot(app, screen: "reader-sidebar", theme: "sepia")
    }

    /// The Mac window.
    func testMacWindow() throws {
        try XCTSkipUnless(TestPlatform.isMac, "macOS only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranTheme", "sepia", "-quranPage", "50"])
        waitForReader(app)
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 15))
        captureScreenshot(app, screen: "reader-window", theme: "sepia")
    }
}
