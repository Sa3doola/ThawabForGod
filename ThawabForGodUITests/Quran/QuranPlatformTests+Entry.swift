//
//  QuranPlatformTests+Entry.swift
//  ThawabForGodUITests
//
//  M8-C2 batch B: the ways into the Quran from outside it. The Home Continue card and recent-activity
//  chip, the three `noor://quran…` links, and a relaunch that keeps the reader's place.
//
//  No new app identifier: the Home chip carries none, so it is matched by its label (kind title,
//  then the surah's name), as decision D3 recommends. Those two labels are English: English runs.
//

import XCTest

extension QuranPlatformTests {
    /// What a flow that reads, moves and leaves leaves behind.
    struct MovedPosition {
        let full: Bool
        let names: Set<String>
        let labels: Set<String>
        /// The pages on screen (one, or two in a spread); empty for the separated reader.
        var pages: [Int] = []
    }

    /// Opens the reader, moves it off its opening place and returns what was on screen.
    /// Full data: Mushaf page 50, then one page on (51). Public data: separated Al-Kahf, scrolled twice.
    func openAndMoveReader(_ app: XCUIApplication) -> MovedPosition {
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)
        if app.hasDisplayModeControl {
            XCTAssertTrue(turnOnePage(in: app), "the pager turned to the next page")
            XCTAssertTrue(waitForOnScreenFooter(in: app), "a footer is on screen")
            return MovedPosition(full: true, names: onScreenSurahNames(in: app), labels: onScreenAyahLabels(in: app),
                                 pages: onScreenPageNumbers(in: app))
        }
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "18"])
        waitForReader(app)
        for _ in 0..<2 { scrollReaderForward(app) }
        return MovedPosition(full: false, names: onScreenSurahNames(in: app), labels: onScreenAyahLabels(in: app))
    }

    /// One screenful forward in the separated reader.
    func scrollReaderForward(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        #if os(macOS)
        window.scroll(byDeltaX: 0, deltaY: -400)
        #else
        window.swipeUp()
        #endif
    }

    // MARK: Home

    /// After reading, Home's Continue card names the place and reopens it; so does the recent chip.
    func testHomeContinueCardAndChip() throws {
        try XCTSkipIf(TestPlatform.isMac, "Mac, unresolved (BUGS.md B11): the Home recent-activity chip is not found by label on the Mac; passes on iOS")
        let app = XCUIApplication()
        let moved = openAndMoveReader(app)
        let name = try XCTUnwrap(moved.names.sorted().first, "the reader showed a surah")

        // Leaving the reader is what writes the position and the recent activity.
        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        selectSection(.home, in: app)

        let card = app.element(id: "home.continueReading")
        XCTAssertTrue(scrollUntilHittable(card, in: app), "Home's Continue reading card")
        XCTAssertTrue(moved.names.contains { card.label.contains($0) }, "the card names the surah, got '\(card.label)'")
        card.tapOrClick()
        waitForReader(app)

        // And again through the recent-activity chip.
        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        selectSection(.home, in: app)
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Quran", name)).firstMatch
        XCTAssertTrue(scrollUntilHittable(chip, in: app), "the Quran chip in recent activity")
        chip.tapOrClick()
        waitForReader(app)
    }

    // MARK: Deep links

    /// `noor://quran` brings the Quran section forward (its Library, or the reader last left open).
    func testDeepLinkQuran() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        selectSection(.home, in: app)

        app.openLink("noor://quran")
        XCTAssertTrue(
            waitForCondition(timeout: 15) { app.libraryTabs.exists || app.readerLibraryButton.exists },
            "the Quran section is in front"
        )
    }

    /// `noor://quran/verse/2/255` opens the reader on Ayat al-Kursi.
    func testDeepLinkVerse() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        selectSection(.home, in: app)

        app.openLink("noor://quran/verse/2/255")
        waitForReader(app)
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 255), in: app, timeout: 15), "ayah 255 is on screen")
    }

    /// `noor://quran/page/50` opens page 50 where there are pages and leaves the Library alone where not.
    func testDeepLinkPage() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        let full = app.libraryHasPages
        selectSection(.home, in: app)

        app.openLink("noor://quran/page/50")
        if full {
            waitForReader(app)
            XCTAssertTrue(waitUntilOnScreen(app.pageFooter(50), in: app, timeout: 15), "page 50's footer is on screen")
        } else {
            XCTAssertTrue(app.libraryTabs.waitForExistence(timeout: 15), "public data: the Library is in front")
            XCTAssertFalse(app.readerLibraryButton.waitForExistence(timeout: 3), "public data: no reader opened")
        }
    }

    // MARK: Relaunch

    /// The place survives the process: after leaving the reader and relaunching, the Library's
    /// Continue bar names it and reopens it.
    func testRelaunchKeepsPosition() throws {
        let app = XCUIApplication()
        let moved = openAndMoveReader(app)
        XCTAssertFalse(moved.names.isEmpty, "the reader showed a surah")

        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        app.terminate()

        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        let bar = app.libraryContinue
        XCTAssertTrue(bar.waitForExistence(timeout: 15), "the Continue reading bar after a relaunch")
        XCTAssertTrue(moved.names.contains { bar.label.contains($0) }, "the bar names the surah, got '\(bar.label)'")
        bar.tapOrClick()
        waitForReader(app)

        if moved.full {
            // The same page or spread comes back (a turn is one page, or two in a spread: 51 is not fixed).
            XCTAssertTrue(waitForPages(moved.pages, in: app, timeout: 15), "pages \(moved.pages) are back on screen")
        } else {
            XCTAssertTrue(
                waitForCondition(timeout: 15) { !self.onScreenAyahLabels(in: app).isDisjoint(with: moved.labels) },
                "an ayah seen before the relaunch is on screen"
            )
        }
    }
}
