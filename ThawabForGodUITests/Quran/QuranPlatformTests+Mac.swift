//
//  QuranPlatformTests+Mac.swift
//  ThawabForGodUITests
//
//  M8-C2, batch C: what only the Mac has. The Quran menu (enabled only while the Quran section is
//  showing), the window changing size between a spread and a single page, and the Settings window
//  (⌘,) with its Quran tab.
//
//  Menu titles are the English strings, so these run in the English run only.
//

import XCTest

#if os(macOS)

extension QuranPlatformTests {
    /// The item `title` of the Quran menu, once the menu has been opened.
    @MainActor
    private func quranMenuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.menuBars.menuBarItems["Quran"].menus.menuItems[title]
    }

    /// Opens the Quran menu, reads whether each of `titles` is enabled, and closes the menu again.
    @MainActor
    private func quranMenuEnablement(_ titles: [String], in app: XCUIApplication) -> [String: Bool] {
        let menu = app.menuBars.menuBarItems["Quran"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "the Quran menu exists in the menu bar")
        menu.click()
        var result: [String: Bool] = [:]
        for title in titles {
            let item = quranMenuItem(title, in: app)
            XCTAssertTrue(item.waitForExistence(timeout: 5), "the Quran menu has '\(title)'")
            result[title] = item.isEnabled
        }
        // Close it. Its items stay in the accessibility tree afterwards, so there is nothing to wait for.
        app.typeKey(.escape, modifierFlags: [])
        return result
    }

    /// The Quran menu follows the section: page commands in the reader only, Search and Go to in the
    /// Quran section's Library too, and everything off in another section.
    @MainActor
    func testMacQuranMenuEnablement() throws {
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "1"])
        waitForReader(app)

        let reader = quranMenuEnablement(["Next page", "Search", "Go to…"], in: app)
        XCTAssertEqual(reader["Next page"], true, "reader: Next page is enabled")
        XCTAssertEqual(reader["Search"], true, "reader: Search is enabled")
        XCTAssertEqual(reader["Go to…"], true, "reader: Go to is enabled")

        app.readerLibraryButton.click()
        waitForLibrary(app)
        let library = quranMenuEnablement(["Next page", "Search", "Go to…"], in: app)
        XCTAssertEqual(library["Next page"], false, "Library: Next page is disabled")
        XCTAssertEqual(library["Search"], true, "Library: Search is enabled")
        XCTAssertEqual(library["Go to…"], true, "Library: Go to is enabled")

        let home = app.element(id: "app.sidebar.home")
        XCTAssertTrue(home.waitForExistence(timeout: 10), "the sidebar's Home row")
        home.click()
        let elsewhere = quranMenuEnablement(["Search", "Go to…"], in: app)
        XCTAssertEqual(elsewhere["Search"], false, "Home: Search is disabled")
        XCTAssertEqual(elsewhere["Go to…"], false, "Home: Go to is disabled")
    }

    /// Dragging the window's bottom-right corner: wide enough shows a spread of two pages, narrow
    /// shows one, and the page being read is still on screen after each change.
    @MainActor
    func testMacResizeSpreadToSingle() throws {
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)

        let window = app.windows.firstMatch
        func resize(toWidth width: CGFloat, height: CGFloat) -> Bool {
            let before = window.frame
            let corner = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: before.width - 2, dy: before.height - 2))
            let target = window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: width - 2, dy: height - 2))
            corner.click(forDuration: 0.1, thenDragTo: target)
            return waitForDeviceCondition(timeout: 6) { abs(window.frame.width - before.width) > 20 }
        }

        // Make sure to start from a known side of the breakpoint: wide first.
        if onScreenPageNumbers(in: app).count != 2 {
            try XCTSkipUnless(resize(toWidth: 1500, height: 950), "the window frame did not change (screen too small, or the corner was not grabbed)")
        }
        XCTAssertTrue(waitForDeviceCondition { let pages = self.onScreenPageNumbers(in: app); return pages.count == 2 && pages.contains(50) },
                      "wide: a spread including page 50; saw \(onScreenPageNumbers(in: app))")

        try XCTSkipUnless(resize(toWidth: 700, height: 900), "the window frame did not change when narrowing")
        XCTAssertTrue(waitForDeviceCondition { let pages = self.onScreenPageNumbers(in: app); return pages.count == 1 && pages.contains(50) },
                      "narrow: a single page, still 50; saw \(onScreenPageNumbers(in: app))")
    }

    /// ⌘, opens the Settings window; its Quran tab shows the reader's settings and the Sources screen.
    @MainActor
    func testMacSettingsQuranTab() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary()
        waitForLibrary(app)

        app.pressShortcut(",")
        let tab = app.toolbars.buttons["Quran"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "the Settings window's Quran tab")
        tab.click()
        XCTAssertTrue(app.element(id: "quran.settings.form").waitForExistence(timeout: 10), "the Quran settings form")
        XCTAssertTrue(app.element(id: "quran.settings.sources").waitForExistence(timeout: 5), "the Sources row")
    }
}

#endif
