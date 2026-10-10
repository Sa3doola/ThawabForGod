//
//  QuranImmersiveTests.swift
//  ThawabForGodUITests
//
//  M5.1: iPhone immersive reading (a tap outside the text hides the navigation bar and the tab bar)
//  and its absence on iPad. Full data only.
//
//  Not covered: "immersive ends when the reader leaves the screen" (hide the bars, open noor://home).
//  That needs XCUIApplication.open(_:), which this author could not confirm exists at the project's
//  SDK, and a custom-scheme URL opened from outside raises a system confirmation on iOS. The rule
//  (`isOnScreen` and `exitImmersive()`) is unit-tested in QuranReaderViewModelTests.
//

import XCTest

@MainActor
final class QuranImmersiveTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// iPhone. The edges turn the page (left is next, right is previous); the footer is outside the
    /// text, so a tap on it hides the Library button and the tab bar, and a second brings both back.
    func testTapZonesAndChrome() throws {
        try XCTSkipUnless(TestPlatform.isPhone, "Immersive reading is iPhone only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))
        XCTAssertTrue(app.appTabBar.exists, "the reader sits inside the tab bar")
        let window = app.windows.firstMatch

        // The left edge, halfway down, is the next page; the right edge is back.
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.55)).tapOrClick()
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(51), in: app), "left edge = next page")
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.55)).tapOrClick()
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app), "right edge = previous page")

        // The footer, in the middle: outside the text.
        let library = app.readerLibraryButton
        XCTAssertTrue(library.exists)
        app.pageFooter(50).tapOrClick()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), "navigation bar hidden")
        XCTAssertTrue(app.appTabBar.waitForNonExistence(timeout: 5), "tab bar hidden")
        captureScreenshot(app, screen: "reader-mushaf-immersive", theme: "paper")

        app.pageFooter(50).tapOrClick()
        XCTAssertTrue(library.waitForExistence(timeout: 5), "navigation bar back")
        XCTAssertTrue(app.appTabBar.waitForExistence(timeout: 5), "tab bar back")
    }

    /// iPhone. `-quranImmersive YES` starts with both bars hidden.
    func testLaunchOptionStartsImmersive() throws {
        try XCTSkipUnless(TestPlatform.isPhone, "Immersive reading is iPhone only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50", "-quranImmersive", "YES"])
        // The Library button is hidden when immersive, so wait on the content, not the toolbar: a
        // Mushaf footer, or (without pages) ayah rows.
        XCTAssertTrue(app.ayahElements.firstMatch.waitForExistence(timeout: 20), "the reader loaded")
        try XCTSkipUnless(app.anyPageFooter.exists, "This build has no Mushaf pages (public data)")
        XCTAssertTrue(app.readerLibraryButton.waitForNonExistence(timeout: 5), "navigation bar hidden at launch")
        XCTAssertTrue(app.appTabBar.waitForNonExistence(timeout: 5), "tab bar hidden at launch")
    }

    /// iPad. No immersive mode: the footer tap leaves the Library button in place.
    func testIPadHasNoImmersiveMode() throws {
        try XCTSkipUnless(TestPlatform.isPad, "iPad only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))

        app.pageFooter(50).tapOrClick()
        // Absence of an effect can only be waited for: the bar must stay for the whole timeout.
        XCTAssertFalse(app.readerLibraryButton.waitForNonExistence(timeout: 2), "the Library button stays on iPad")
        XCTAssertTrue(app.readerLibraryButton.isHittable)
    }
}
