//
//  QuranPlatformTests+Content.swift
//  ThawabForGodUITests
//
//  M8-C2 batch B: the Library's Arabic filter, the Bookmarks list, Search, the reader's settings
//  sheet and the Settings tab's Quran page with Sources & Licences.
//
//  Every Arabic string is written with \u{} escapes: Arabic literals reorder in source. The search
//  highlight cannot be asserted (XCUITest cannot read a background colour), so the results are
//  attached as a screenshot for eyes.
//

import XCTest

extension QuranPlatformTests {
    // MARK: Library filter

    /// Typing "الكهف" leaves Al-Kahf (18) and removes Al-Fatiha (1); clearing brings it back.
    /// Both data modes, both languages.
    func testLibraryFilterArabic() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah, [], language: TestRun.language)
        waitForLibrary(app)

        app.typeInLibraryField("\u{0627}\u{0644}\u{0643}\u{0647}\u{0641}")
        XCTAssertTrue(app.surahRow(18).waitForExistence(timeout: 10), "Al-Kahf matches the Arabic filter")
        XCTAssertTrue(app.surahRow(1).waitForNonExistence(timeout: 10), "Al-Fatiha is filtered out")

        XCTAssertTrue(app.libraryClear.waitForExistence(timeout: 5), "the field's clear button")
        app.libraryClear.tapOrClick()
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10), "clearing brings the full list back")
    }

    // MARK: Bookmarks

    /// The marks list: 5 bookmarks, 3 notes, 6 highlights from the seed, a row opens the reader; with
    /// no marks the list says so.
    func testBookmarksListKindsAndOpen() throws {
        try XCTSkipIf(TestPlatform.isMac, "Mac, unresolved (BUGS.md B11): clicking the Notes segment does not switch the list under XCUITest; works on iOS")
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah, ["-quranResetUserData", "YES", "-quranSeedUserData", "YES"])
        waitForLibrary(app)

        app.element(id: "quran.library.bookmarks").tapOrClick()
        XCTAssertTrue(app.element(id: "quran.bookmarks.list").waitForExistence(timeout: 10), "the marks list")
        XCTAssertTrue(waitForCondition { self.markRowLabels(in: app).count == 5 }, "5 bookmarks, got \(markRowLabels(in: app).count)")

        // The kind picker's segments by title (English runs): on the Mac the picker's identifier sits on
        // a container whose descendants are the list's rows too, so index-based lookup hit a row.
        func segment(_ title: String, _ index: Int) -> XCUIElement {
            #if os(macOS)
            return app.radioButtons[title].firstMatch
            #else
            return app.pickerSegments("quran.bookmarks.kind").element(boundBy: index)
            #endif
        }
        XCTAssertTrue(segment("Notes", 1).waitForExistence(timeout: 10), "the Notes segment")
        segment("Notes", 1).tapOrClick()
        XCTAssertTrue(waitForCondition { self.markRowLabels(in: app).count == 3 }, "3 notes, got \(markRowLabels(in: app).count)")
        segment("Highlights", 2).tapOrClick()
        XCTAssertTrue(waitForCondition { self.markRowLabels(in: app).count == 6 }, "6 highlights, got \(markRowLabels(in: app).count)")

        let row = app.descendants(matching: .any).matching(identifier: "quran.bookmarks.row").firstMatch
        row.tapOrClick()
        waitForReader(app)

        // Reset on one launch (it clears the stored marks), then a plain relaunch: the removal was
        // persisted, so the list is empty. (The reset launch itself can show marks the store loads
        // after the debug reset ran, so it is not the launch that asserts.)
        app.launchPlatformLibrary(.surah, ["-quranResetUserData", "YES"])
        waitForLibrary(app)
        app.terminate()
        app.launchPlatformLibrary(.surah, [])
        waitForLibrary(app)
        app.element(id: "quran.library.bookmarks").tapOrClick()
        XCTAssertTrue(app.element(id: "quran.bookmarks.empty").waitForExistence(timeout: 10), "no marks: the empty state")
    }

    /// The distinct labels of the mark rows: a row's combined element may be matched twice (the
    /// button and its content), the label is one per mark.
    func markRowLabels(in app: XCUIApplication) -> Set<String> {
        let rows = app.descendants(matching: .any).matching(identifier: "quran.bookmarks.row")
        var labels = Set<String>()
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if row.exists { labels.insert(row.label) }
        }
        return labels
    }

    // MARK: Search

    /// Searching كهيعص finds 19:1; a result opens the reader on it; the query is among the recent
    /// searches afterwards. Both data modes, both languages.
    func testSearchOpensResultAndRemembers() throws {
        let query = "\u{0643}\u{0647}\u{064A}\u{0639}\u{0635}"
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah, [], language: TestRun.language)
        waitForLibrary(app)

        app.element(id: "quran.library.search").tapOrClick()
        // Recents outlive launches: start without them.
        let clearRecents = app.element(id: "quran.search.recent.clear")
        if clearRecents.waitForExistence(timeout: 3) { clearRecents.tapOrClick() }

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "the search field")
        field.tapOrClick()
        field.typeText(query + "\n")

        XCTAssertTrue(app.element(id: "quran.search.count").waitForExistence(timeout: 15), "the result count")
        let result = app.element(id: "quran.search.result")
        XCTAssertTrue(result.waitForExistence(timeout: 15), "at least one result")
        captureScreenshot(app, screen: "search-results", theme: themeName)

        result.tapOrClick()
        waitForReader(app)
        if TestRun.language == .english {
            XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 1), in: app), "ayah 1 of the surah is on screen")
        }

        // Back out to the Library and into Search again: the last query's results are still there.
        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        app.element(id: "quran.library.search").tapOrClick()
        XCTAssertTrue(app.element(id: "quran.search.result").waitForExistence(timeout: 10), "reopening Search keeps the last results")

        // And the query is a recent search: after a relaunch the screen starts empty and lists it.
        app.terminate()
        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        app.element(id: "quran.library.search").tapOrClick()
        let recent = app.element(id: "quran.search.recent")
        XCTAssertTrue(recent.waitForExistence(timeout: 10), "the recent searches")
        XCTAssertTrue(recent.label.contains(query), "the recent search is the query, got '\(recent.label)'")
    }

    // MARK: Settings

    /// The reader's settings sheet: the display-mode picker exists only where there are pages (and
    /// switching it leaves the page footers behind); the phone-only landscape picker is there on a phone.
    func testReaderSettingsSheet() throws {
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)
        let full = app.hasDisplayModeControl

        app.openReaderSettings()
        XCTAssertTrue(app.element(id: "quran.settings.form").waitForExistence(timeout: 10), "the settings form")

        let displayMode = app.element(id: "quran.settings.displayMode")
        if full {
            XCTAssertTrue(displayMode.waitForExistence(timeout: 5), "the display-mode picker")
            app.pickerSegments("quran.settings.displayMode").element(boundBy: 1).tapOrClick()
        } else {
            XCTAssertFalse(displayMode.exists, "public data has one display mode: no picker")
        }

        if TestPlatform.isPhone {
            XCTAssertTrue(scrollUntilHittable(app.element(id: "quran.settings.landscape"), in: app), "the phone's landscape picker")
        }

        let done = app.element(id: "quran.settings.done")
        // After scrolling to the phone-only pickers the bar can be scrolled out of view (the Duo's sheet
        // lets it go): scroll back to the top where Done is.
        for _ in 0..<5 where !done.isHittable { app.windows.firstMatch.swipeDown() }
        XCTAssertTrue(done.exists, "Done")
        done.tapOrClick()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10), "the sheet closed")
        if full {
            XCTAssertTrue(app.anyPageFooter.waitForNonExistence(timeout: 10), "separated mode has no page footer")
        }
    }

    /// iOS: Settings -> Quran shows the same form, and Sources & Licences lists the full data only
    /// where the build has it.
    func testSettingsQuranAndSources() throws {
        try XCTSkipIf(TestPlatform.isMac, "The Mac reaches Quran settings through the Settings window (batch C).")
        let app = XCUIApplication()
        app.launchPlatformLibrary(.surah)
        waitForLibrary(app)
        let full = app.libraryHasPages

        selectSection(.settings, in: app)
        let quran = app.collectionViews.buttons["Quran"]
        XCTAssertTrue(quran.waitForExistence(timeout: 10), "Settings has a Quran row")
        quran.tap()
        XCTAssertTrue(app.element(id: "quran.settings.form").waitForExistence(timeout: 10), "the Quran settings form")

        let sources = app.element(id: "quran.settings.sources")
        XCTAssertTrue(scrollUntilHittable(sources, in: app), "the Sources row")
        sources.tap()
        XCTAssertTrue(app.titleText("Sources & Licences").waitForExistence(timeout: 10), "the Sources & Licences screen")

        if full {
            XCTAssertTrue(waitForText("Quran text and page layout", in: app), "the full data's source is listed")
        } else {
            XCTAssertTrue(waitForText("The Quran", in: app), "the fallback's source is listed")
            XCTAssertFalse(waitForText("Quran text and page layout", in: app, timeout: 1), "the full data is not claimed")
        }
    }
}
