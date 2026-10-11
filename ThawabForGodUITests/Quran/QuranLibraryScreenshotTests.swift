//
//  QuranLibraryScreenshotTests.swift
//  ThawabForGodUITests
//
//  M5.2 screenshots, for eyes and not assertions. Each is attached to the test and, with
//  TEST_RUNNER_QURAN_SCREENSHOT_DIR set, written to
//  Screenshots/quran-migration/M5/M5.2/<device>-<screen>-<theme>.png (git-ignored). The Library is
//  an app screen, so the themes are the app's own: light and dark (`-AppleInterfaceStyle`).
//  Run on an iPhone SE, an iPhone 17 Pro, an iPad (sidebar arrangement) and the Mac.
//

import XCTest

@MainActor
final class QuranLibraryScreenshotTests: XCTestCase {
    private let appearances: [(theme: String, style: String)] = [("light", "Light"), ("dark", "Dark")]

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func options(_ style: String, _ extra: [String] = []) -> [String] {
        ["-AppleInterfaceStyle", style] + extra
    }

    /// Each index in light and dark; the Page tab only where the build has it.
    func testEachIndex() throws {
        for appearance in appearances {
            let app = XCUIApplication()
            app.launchQuranLibrary(.surah, options(appearance.style))
            waitForLibrary(app)
            XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-surah", theme: appearance.theme)

            app.selectLibraryTab(.juz)
            XCTAssertTrue(app.juzRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-juz", theme: appearance.theme)

            app.selectLibraryTab(.hizb)
            XCTAssertTrue(app.hizbRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-hizb", theme: appearance.theme)

            if app.libraryHasPages {
                app.selectLibraryTab(.page)
                XCTAssertTrue(app.pageCell(1).waitForExistence(timeout: 10))
                captureScreenshot(app, screen: "library-page", theme: appearance.theme)
            }
            app.terminate()
        }
    }

    /// The public build's three tabs.
    func testPublicTabs() throws {
        for appearance in appearances {
            let app = XCUIApplication()
            app.launchQuranLibrary(.surah, options(appearance.style, ["-quranData", "public"]))
            waitForLibrary(app)
            XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-public-surah", theme: appearance.theme)
            app.selectLibraryTab(.juz)
            XCTAssertTrue(app.juzRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-public-juz", theme: appearance.theme)
            app.selectLibraryTab(.hizb)
            XCTAssertTrue(app.hizbRow(1).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-public-hizb", theme: appearance.theme)
            app.terminate()
        }
    }

    /// The failure line, a filtered list and the empty filter.
    func testFieldStates() throws {
        for appearance in appearances {
            let app = XCUIApplication()
            app.launchQuranLibrary(.surah, options(appearance.style, ["-quranData", "public"]))
            waitForLibrary(app)

            app.typeInLibraryField("page 50", submit: true)
            XCTAssertTrue(app.libraryError.waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-error", theme: appearance.theme)
            app.libraryClear.tapOrClick()

            app.libraryQuery.tapOrClick()
            app.libraryQuery.typeText("kahf")
            XCTAssertTrue(app.surahRow(18).waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-filtered", theme: appearance.theme)
            app.libraryClear.tapOrClick()

            app.libraryQuery.tapOrClick()
            app.libraryQuery.typeText("zzz")
            XCTAssertTrue(app.libraryEmpty.waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-empty", theme: appearance.theme)
            app.terminate()
        }
    }

    /// The Continue reading row, after a visit to the reader.
    func testContinueReading() throws {
        for appearance in appearances {
            let app = XCUIApplication()
            app.launchQuranLibrary(.surah, options(appearance.style))
            waitForLibrary(app)
            openSurahFromLibrary(18, in: app)
            app.readerLibraryButton.tapOrClick()
            waitForLibrary(app)
            XCTAssertTrue(app.libraryContinue.waitForExistence(timeout: 10))
            captureScreenshot(app, screen: "library-continue", theme: appearance.theme)
            app.terminate()
        }
    }

    /// Surah info, where the pack is bundled.
    func testSurahInfo() throws {
        for appearance in appearances {
            let app = XCUIApplication()
            app.launchQuranLibrary(.surah, options(appearance.style))
            waitForLibrary(app)
            scrollToSurahRow(18, in: app)
            app.revealSurahInfoAction(on: app.surahRow(18))
            try XCTSkipUnless(app.surahInfoAction.waitForExistence(timeout: 5), "No surah-info pack in this build.")
            app.surahInfoAction.tapOrClick()
            XCTAssertTrue(app.surahInfoText.waitForExistence(timeout: 20))
            captureScreenshot(app, screen: "surah-info", theme: appearance.theme)
            app.terminate()
        }
    }

    /// One Arabic capture of the Surah tab.
    func testArabicSurahTab() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, options("Light"), language: .arabic)
        waitForLibrary(app)
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10))
        captureScreenshot(app, screen: "library-surah-ar", theme: "light")
    }

    /// iPhone only: the Surah tab at the largest accessibility text size (the picker becomes a menu).
    func testLargestAccessibilityTextSize() throws {
        try XCTSkipUnless(TestPlatform.isPhone, "iPhone only: the Mac has no content-size category and the iPad is not in the note")
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, options("Light", [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]))
        waitForLibrary(app)
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10))
        captureScreenshot(app, screen: "library-surah-axxxl", theme: "light")
    }
}
