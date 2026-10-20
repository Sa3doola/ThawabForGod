//
//  QuranSidePanelTests.swift
//  ThawabForGodUITests
//
//  M8-B2: the ayah panel is a trailing column inside the reader (Mac, iPad regular-width landscape)
//  and a sheet elsewhere; there is no `.inspector`, which popped the pushed reader.
//
//  Identifiers this file relies on: `quran.sidePanel` (the column's container), `quran.panel.close`
//  (the stepper's Close, present in both placements) and `quran.panel.done` (the sheet's Done,
//  present only in the sheet placement). An iPad is rotated through `XCUIDevice` before launch;
//  an iPhone never gets a column, so the column flows skip there.
//

import XCTest

@MainActor
final class QuranSidePanelTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private var panelLaunch: [String] {
        ["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255", "-quranPanel", "2:255"]
    }

    /// Rotates an iPad before launch; a no-op on the Mac (which has no device orientation).
    private func setLandscape(_ landscape: Bool) {
        #if os(iOS)
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        #endif
    }

    /// B2 regression, every platform, public data: tapping a surah in the Library opens the reader
    /// and it stays open (it used to be popped straight back on the Mac).
    func testLibraryTapOpensReader() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranData", "public"])
        waitForLibrary(app)
        openSurahFromLibrary(1, in: app)

        XCTAssertFalse(app.libraryList.waitForExistence(timeout: 3), "the reader was not popped back to the Library")
        XCTAssertTrue(app.readerLibraryButton.exists, "the reader is still in front")
    }

    /// Mac and iPad landscape: the panel is a column beside the reader, on the trailing side, and
    /// closing it leaves the reader where it was.
    func testSidePanelBesideReader() throws {
        try XCTSkipIf(TestPlatform.isPhone, "an iPhone always presents the panel as a sheet")
        if TestPlatform.isPad { setLandscape(true) }

        let app = XCUIApplication()
        app.launchQuran(panelLaunch)
        waitForReader(app)

        let panel = app.element(id: "quran.sidePanel")
        XCTAssertTrue(panel.waitForExistence(timeout: 15), "the side panel column")
        XCTAssertTrue(app.element(id: "quran.panel.close").waitForExistence(timeout: 5), "the panel's Close")
        XCTAssertFalse(app.element(id: "quran.panel.done").exists, "no sheet Done: it is a column, not a sheet")

        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(panel.frame.minX, window.midX, "English: the trailing edge is the right")

        XCTAssertFalse(app.readerLibraryButton.waitForNonExistence(timeout: 3), "the reader stays beside the panel")

        app.element(id: "quran.panel.close").tapOrClick()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 10), "Close removes the column")
        XCTAssertTrue(app.readerLibraryButton.exists, "the reader is still there")
    }

    /// iPad in portrait: not wide enough for a column, so the panel is the sheet.
    func testPortraitPadUsesSheet() throws {
        try XCTSkipUnless(TestPlatform.isPad, "iPad only")
        setLandscape(false)

        let app = XCUIApplication()
        app.launchQuran(panelLaunch)
        waitForReader(app)

        XCTAssertTrue(app.element(id: "quran.panel.done").waitForExistence(timeout: 15), "the sheet's Done")
        XCTAssertFalse(app.element(id: "quran.sidePanel").exists, "no side column in portrait")
    }

    /// Mac, Arabic interface: the trailing edge is the left, so the column sits left of the middle.
    func testSidePanelInArabicIsLeading() throws {
        try XCTSkipUnless(TestPlatform.isMac, "Mac only")

        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", TestLanguage.arabic.languages, "-AppleLocale", TestLanguage.arabic.locale,
            "-quranResetSettings", "YES", "-quranFollowSystem", "NO", "-ApplePersistenceIgnoreState", "YES",
        ] + panelLaunch
        app.launch()
        waitForReader(app)

        let panel = app.element(id: "quran.sidePanel")
        XCTAssertTrue(panel.waitForExistence(timeout: 15), "the side panel column")
        // The column follows the window's layout direction. If the Mac window itself is not
        // mirrored in Arabic (the sidebar stays on the left), there is nothing to mirror: BUGS.md B7.
        let window = app.windows.firstMatch.frame
        let sidebar = app.element(id: "app.sidebar.quran")
        try XCTSkipUnless(sidebar.waitForExistence(timeout: 10) && sidebar.frame.midX > window.midX,
                          "the Mac window is not mirrored in Arabic (B7), so the panel stays on the right")
        XCTAssertLessThan(panel.frame.maxX, window.midX, "Arabic: the trailing edge is the left")
    }
}
