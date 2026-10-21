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

    /// iPhone. Taps never turn a page: a tap on a word selects its ayah (the panel opens), whichever
    /// edge of the line it is on, and the page stays 50. The footer is outside the text, so a tap
    /// on it hides the Library button and the tab bar, and a second brings both back; a word tap
    /// while the bars are hidden still selects its ayah.
    func testTapsNeverTurnAndFooterTogglesChrome() throws {
        try XCTSkipUnless(TestPlatform.isPhone, "Immersive reading is iPhone only")
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15))
        // A compact phone has a bottom tab bar. The Duo's wide arrangement draws its sections
        // differently (a side tab bar that XCUITest does not report as a tab bar), so there the
        // test checks the navigation bar only (BUGS.md B13).
        let hasTabBar = app.appTabBar.waitForExistence(timeout: 3)

        // The first word and the last word of a line sat in the old edge zones: neither turns now.
        for edge in [WordEdge.first, .last] {
            let ayah = try XCTUnwrap(ayahsInBody(of: app, count: 1).first, "an ayah in the body of page 50")
            tapWord(of: ayah, edge: edge, in: app)
            dismissAyahPanel(in: app, opened: "a word tap opens the ayah panel (\(edge))")
            XCTAssertTrue(waitForPages([50], in: app), "a word tap did not turn the page (\(edge))")
        }

        // The footer, in the middle: outside the text.
        let library = app.readerLibraryButton
        XCTAssertTrue(library.exists)
        app.pageFooter(50).tapOrClick()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), "navigation bar hidden")
        if hasTabBar { XCTAssertTrue(app.appTabBar.waitForNonExistence(timeout: 5), "tab bar hidden") }
        captureScreenshot(app, screen: "reader-mushaf-immersive", theme: "paper")

        // Immersive: a word still selects its ayah and the page still does not change.
        let ayah = try XCTUnwrap(ayahsInBody(of: app, count: 1).first, "an ayah in the body while immersive")
        tapWord(of: ayah, edge: .first, in: app)
        dismissAyahPanel(in: app, opened: "a word tap while immersive opens the panel")
        XCTAssertTrue(waitForPages([50], in: app), "still page 50 after the immersive word tap")

        // Bring the bars back with the footer, if the panel left them hidden.
        if !library.exists {
            app.pageFooter(50).tapOrClick()
        }
        XCTAssertTrue(library.waitForExistence(timeout: 5), "navigation bar back")
        if hasTabBar { XCTAssertTrue(app.appTabBar.waitForExistence(timeout: 5), "tab bar back") }
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
        // Missing is also what hidden looks like; the compact-phone case is held by the other test.
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
