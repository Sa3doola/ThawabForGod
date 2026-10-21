//
//  QuranPlatformTests+Devices.swift
//  ThawabForGodUITests
//
//  M8-C2, batch C: what only some devices have. iPad rotation with the ayah panel open, the
//  keyboard shortcuts (iPad with a hardware keyboard, Mac) and the Duo's fold geometry.
//
//  The Duo cannot be folded from a script: the DEBUG `-quranFold` / `-quranFoldHorizontal` override
//  is fixed for the life of a launch (decision D1). `testDuoRotateWithPanel` rotates the device
//  twice as a stand-in for a fold change; the real fold/unfold is a manual check on hardware.
//

import XCTest

// MARK: - Shared by batch C

extension QuranPlatformTests {
    /// Waits, with an expectation and never a sleep, until `condition` holds.
    @MainActor
    func waitForDeviceCondition(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    /// Rotates the device; a no-op on the Mac, which has no orientation.
    @MainActor
    func setDeviceOrientation(landscape: Bool) {
        #if os(iOS)
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        #endif
    }

    /// Puts an iPad or Duo back upright when the test ends, so the next test starts from portrait.
    @MainActor
    func restoreOrientationAtEnd() {
        addTeardownBlock { @MainActor in
            #if os(iOS)
            XCUIDevice.shared.orientation = .portrait
            #endif
        }
    }

    /// The ayah panel that is open: its Arabic text, in either placement (column or sheet).
    @MainActor
    func panelArabic(in app: XCUIApplication) -> XCUIElement {
        app.element(id: "quran.panel.arabic")
    }

    var devicePanelLaunch: [String] {
        ["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255", "-quranPanel", "2:255"]
    }
}

// MARK: - iPad rotation

extension QuranPlatformTests {
    /// iPad: the panel is a column in landscape and a sheet in portrait, and rotating swaps one for
    /// the other without closing it or leaving the reader.
    @MainActor
    func testPadRotationKeepsPanel() throws {
        try XCTSkipUnless(TestPlatform.isPad, "iPad only: an iPhone never has a column and the Mac has no rotation")
        restoreOrientationAtEnd()
        setDeviceOrientation(landscape: true)

        let app = XCUIApplication()
        app.launchPlatform(devicePanelLaunch)
        waitForReader(app)
        XCTAssertTrue(app.element(id: "quran.sidePanel").waitForExistence(timeout: 15), "landscape: the panel is a column")

        setDeviceOrientation(landscape: false)
        XCTAssertTrue(app.element(id: "quran.panel.done").waitForExistence(timeout: 15), "portrait: the panel became a sheet")
        XCTAssertTrue(panelArabic(in: app).waitForExistence(timeout: 10), "portrait: the sheet shows the ayah")
        XCTAssertTrue(app.readerLibraryButton.exists, "portrait: the reader stayed")

        setDeviceOrientation(landscape: true)
        XCTAssertTrue(app.element(id: "quran.sidePanel").waitForExistence(timeout: 15), "back in landscape: a column again")
        XCTAssertTrue(panelArabic(in: app).waitForExistence(timeout: 10), "back in landscape: the same ayah")
        XCTAssertTrue(app.readerLibraryButton.exists, "back in landscape: the reader stayed")
    }
}

// MARK: - Keyboard shortcuts

extension QuranPlatformTests {
    /// iPad and Mac: ⌘F opens search from the reader, ⌘G returns to the Library with the go-to field
    /// focused, and neither does anything in another section.
    @MainActor
    func testShortcutsSearchGoTo() throws {
        try XCTSkipUnless(TestPlatform.isPad || TestPlatform.isMac, "needs a hardware keyboard: iPad and Mac")
        if TestPlatform.isPad { setDeviceOrientation(landscape: true); restoreOrientationAtEnd() }

        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "1"])
        waitForReader(app)

        // The reader's key responder takes focus a moment after the reader loads, so the first ⌘F can be
        // lost; send it again once before calling it a failure.
        Thread.sleep(forTimeInterval: 1.5)
        // The Search screen: its field is collapsed into the bar on iPad and is not in the tree, so the
        // screen is recognised by its navigation bar or its empty state too.
        let searchScreen = { app.searchFields.firstMatch.exists || app.navigationBars["Search"].exists || app.element(id: "quran.search.empty").exists }
        app.pressShortcut("f")
        if !waitForDeviceCondition(timeout: 6, { searchScreen() }) { app.pressShortcut("f") }
        XCTAssertTrue(waitForDeviceCondition { searchScreen() }, "⌘F opened search")

        // From the Search screen: ⌘G works anywhere in the Quran section, and it avoids a Back tap
        // (on the Mac the first toolbar button is the sidebar's).
        app.pressShortcut("g")
        XCTAssertTrue(app.libraryQuery.waitForExistence(timeout: 10), "⌘G returned to the Library")
        // That the field has the keyboard is not asserted: under XCUITest the window is not focused
        // the way a real session is (`hasKeyboardFocus` is never true and typed text is lost). It was
        // checked with real keystrokes on the Mac: ⌘F, ⌘G, then typing "2:255" fills the field (M8 notes).

        selectSection(.home, in: app)
        app.pressShortcut("f")
        // Had ⌘F fired on Home it would have pushed Search onto the Quran's stack: so look there.
        selectSection(.quran, in: app)
        XCTAssertTrue(app.libraryQuery.waitForExistence(timeout: 10), "back in the Quran: its Library is the screen in front")
        XCTAssertFalse(app.navigationBars["Search"].exists, "⌘F does nothing outside the Quran section")
    }

    /// iPad and Mac: ⌘D keeps the selected ayah; the Bookmarks list then has exactly one row.
    @MainActor
    func testShortcutBookmark() throws {
        try XCTSkipUnless(TestPlatform.isPad || TestPlatform.isMac, "needs a hardware keyboard: iPad and Mac")
        if TestPlatform.isPad { setDeviceOrientation(landscape: true); restoreOrientationAtEnd() }

        let app = XCUIApplication()
        // ⌘D toggles, so it must start with no mark on 2:255. The debug reset clears the stored marks
        // but a store that loads after it can bring an old one back: reset on one launch, press ⌘D on
        // a plain relaunch.
        app.launchPlatformLibrary(.surah, ["-quranResetUserData", "YES"])
        waitForLibrary(app)
        app.terminate()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255", "-quranSelect", "2:255"])
        waitForReader(app)
        XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 15), "ayah 255 is on screen")

        app.pressShortcut("d")

        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        let bookmarks = app.element(id: "quran.library.bookmarks")
        XCTAssertTrue(bookmarks.waitForExistence(timeout: 10), "the Library's Bookmarks button")
        bookmarks.tapOrClick()
        XCTAssertTrue(app.element(id: "quran.bookmarks.list").waitForExistence(timeout: 10), "the Bookmarks list")
        let rows = app.descendants(matching: .any).matching(identifier: "quran.bookmarks.row")
        XCTAssertTrue(waitForDeviceCondition { rows.count == 1 }, "⌘D kept exactly one ayah; rows: \(rows.count)")
    }

    /// iPad and Mac: ⌘] opens the next surah and ⌘[ the previous one, back to where it began.
    @MainActor
    func testShortcutsSurah() throws {
        try XCTSkipUnless(TestPlatform.isPad || TestPlatform.isMac, "needs a hardware keyboard: iPad and Mac")
        if TestPlatform.isPad { setDeviceOrientation(landscape: true); restoreOrientationAtEnd() }

        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "2"])
        waitForReader(app)
        XCTAssertTrue(waitForDeviceCondition { !self.onScreenSurahNames(in: app).isEmpty }, "the reader shows a surah")
        let original = onScreenSurahNames(in: app)

        app.pressShortcut("]")
        XCTAssertTrue(waitForDeviceCondition { let now = self.onScreenSurahNames(in: app); return !now.isEmpty && now != original },
                      "⌘] moved to another surah")

        app.pressShortcut("[")
        XCTAssertTrue(waitForDeviceCondition { self.onScreenSurahNames(in: app) == original }, "⌘[ came back to the first surah")
    }
}

// MARK: - Surface Duo

extension QuranPlatformTests {
    /// Duo unfolded (posed with the override): two pages side by side, the opening page among them,
    /// and one swipe turns to the next spread.
    @MainActor
    func testDuoSpread() throws {
        try XCTSkipUnless(TestPlatform.isFoldable, "Surface Duo only")
        let app = XCUIApplication()
        app.launchPlatform(["-quranFold", "0.5,24", "-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)

        XCTAssertTrue(waitForDeviceCondition { let pages = self.onScreenPageNumbers(in: app); return pages.count == 2 && pages.contains(50) },
                      "a spread of two pages, one of them 50; saw \(onScreenPageNumbers(in: app))")
        XCTAssertTrue(turnOnePage(in: app), "a swipe turned to the next spread")
    }

    /// Duo folded (the simulator posed folded, no override): one page. Skipped unless the window is
    /// narrow, because an unfolded or non-Duo run has nothing to say here.
    @MainActor
    func testDuoFolded() throws {
        try XCTSkipUnless(TestPlatform.isFoldable, "Surface Duo only")
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "50"])
        try requireMushafPages(app)
        try XCTSkipUnless(app.windows.firstMatch.frame.width < 500, "the simulator is not posed folded (window is wide)")

        XCTAssertTrue(waitForDeviceCondition { self.onScreenPageNumbers(in: app) == [50] },
                      "folded: one page, 50; saw \(onScreenPageNumbers(in: app))")
    }

    /// Duo in tabletop (the horizontal fold override): the page above the hinge and the panel below
    /// it, with its own previous/next controls; next turns the page and Close removes the panel.
    @MainActor
    func testDuoTabletopPanel() throws {
        try XCTSkipUnless(TestPlatform.isFoldable, "Surface Duo only")
        let app = XCUIApplication()
        app.launchPlatform(["-quranFoldHorizontal", "0.5,24", "-quranMode", "mushaf", "-quranPage", "42",
                            "-quranPanel", "2:255"])
        try requireMushafPages(app)

        // The bottom half shows the panel, or (once it is closed) the page buttons: not both.
        let close = app.element(id: "quran.tabletop.closePanel")
        XCTAssertTrue(close.waitForExistence(timeout: 15), "the tabletop panel's Close")
        close.tapOrClick()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "Close removed the panel")

        let next = app.element(id: "quran.tabletop.nextPage")
        XCTAssertTrue(next.waitForExistence(timeout: 10), "the page buttons replace the panel: next page")
        next.tapOrClick()
        XCTAssertTrue(waitUntilOnScreen(app.pageFooter(43), in: app), "next turned the page to 43")
    }

    /// Rotating the Duo with the panel open (a stand-in for a fold change, decision D1): the panel,
    /// the ayah it shows and the reader all survive two rotations.
    @MainActor
    func testDuoRotateWithPanel() throws {
        try XCTSkipUnless(TestPlatform.isFoldable, "Surface Duo only")
        restoreOrientationAtEnd()
        let app = XCUIApplication()
        app.launchPlatform(["-quranFold", "0.5,24", "-quranMode", "mushaf", "-quranPage", "42", "-quranPanel", "2:255"])
        try requireMushafPages(app)

        let arabic = panelArabic(in: app)
        XCTAssertTrue(arabic.waitForExistence(timeout: 15), "the panel is open")
        let before = arabic.text

        setDeviceOrientation(landscape: true)
        XCTAssertTrue(arabic.waitForExistence(timeout: 15), "the panel survived the first rotation")
        setDeviceOrientation(landscape: false)
        XCTAssertTrue(arabic.waitForExistence(timeout: 15), "the panel survived the second rotation")

        XCTAssertEqual(arabic.text, before, "the panel still shows the same ayah")
        XCTAssertTrue(app.readerLibraryButton.exists, "the reader stayed")
    }
}
