//
//  QuranLibraryGoToTests.swift
//  ThawabForGodUITests
//
//  M5.2: the Library's one field, which goes to an address and filters the surahs.
//
//  Typing: `typeInLibraryField` taps (clicks) the field, then types; a trailing "\n" is Return, which
//  the field submits as a go. Go with the button is `quran.library.go`. The field's own text cannot
//  be read (an empty field reports its placeholder), so "has text" is "the Clear button exists".
//  Expected places are read from the row of the same number, never typed in.
//

import XCTest

@MainActor
final class QuranLibraryGoToTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Both modes. `2:255` and Return opens the reader on ayah 255 (with pages, on a page); back in
    /// the Library the field is empty.
    func testGoToAnAyah() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranMode", "mushaf"])
        waitForLibrary(app)
        let hasPages = app.libraryHasPages

        app.typeInLibraryField("2:255", submit: true)
        waitForReader(app)
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 255), in: app, timeout: 15), "ayah 255 is on screen")
        if hasPages { XCTAssertTrue(waitForOnScreenFooter(in: app), "a page footer") }

        app.readerLibraryButton.tapOrClick()
        waitForLibrary(app)
        XCTAssertTrue(waitForFieldText(false, in: app), "the field was cleared when the Library opened something")
    }

    /// Both modes. `juz 5` from the Juz tab and `hizb 12` from the Hizb tab each open the reader at
    /// the start ayah their row of the same number names. Separated mode, which both builds have.
    func testGoToADivision() throws {
        let cases: [(tab: LibraryTab, prefix: String, number: Int, text: String)] = [
            (.juz, "juz", 5, "juz 5"), (.hizb, "hizb", 12, "hizb 12"),
        ]
        for item in cases {
            let app = XCUIApplication()
            app.launchQuranLibrary(item.tab, ["-quranMode", "separated"])
            waitForLibrary(app)
            try assertGoToDivision(app, prefix: item.prefix, number: item.number, text: item.text)
            app.terminate()
        }
    }

    /// Both modes. The Arabic words for the same: `جزء ٥` opens juz 5's start.
    func testGoToADivisionWithArabicWords() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.juz, ["-quranMode", "separated"])
        waitForLibrary(app)
        try assertGoToDivision(app, prefix: "juz", number: 5, text: "جزء ٥")
    }

    private func assertGoToDivision(_ app: XCUIApplication, prefix: String, number: Int, text: String) throws {
        scrollToLibraryRow(prefix: prefix, number, in: app)
        let row = app.element(id: "quran.library.\(prefix).\(number)")
        let place = try XCTUnwrap(startPlace(ofRow: row), "the row's label: \(row.label)")

        app.typeInLibraryField(text, submit: true)
        waitForReader(app)
        XCTAssertTrue(waitForText(place.name, in: app), "'\(text)' opens in \(place.name)")
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: place.ayah), in: app, timeout: 15), "'\(text)' lands on ayah \(place.ayah)")
    }

    /// Full data: a bare `50` is page 50, so the Mushaf footer ends "Page 50".
    func testBareNumberIsAPageInTheFullBuild() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranMode", "mushaf"])
        try requireLibraryPages(app)

        app.typeInLibraryField("50", submit: true)
        waitForReader(app)
        XCTAssertTrue(waitForOnScreenFooter(in: app), "a page footer")
        XCTAssertTrue(onScreenFooterText(in: app)?.hasSuffix("Page 50") ?? false, "the footer says Page 50")
    }

    /// Forced public data: a bare `50` is surah 50 (there are no pages), the one row the filter
    /// shows, and ayah 1 of it is on screen.
    func testBareNumberIsASurahInThePublicBuild() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranData", "public"])
        waitForLibrary(app)

        app.typeInLibraryField("50")
        XCTAssertTrue(app.surahRow(50).waitForExistence(timeout: 10), "the filter shows surah 50")
        let name = surahName(ofRow: app.surahRow(50))
        XCTAssertTrue(app.libraryGo.waitForExistence(timeout: 5))
        app.libraryGo.tapOrClick()

        waitForReader(app)
        XCTAssertTrue(waitForText(name, in: app), "the reader shows \(name)")
        XCTAssertTrue(waitUntilOnScreen(app.ayahElement(verse: 1), in: app, timeout: 15), "its first ayah is on screen")
    }

    /// Forced public data. `page 50` is refused by name: the error line is there, the reader is not
    /// pushed, the text is kept; one more character clears the error.
    func testAPageIsRefusedInThePublicBuild() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranData", "public"])
        waitForLibrary(app)

        app.typeInLibraryField("page 50", submit: true)
        XCTAssertTrue(app.libraryError.waitForExistence(timeout: 10), "the refusal")
        XCTAssertFalse(app.libraryHint.exists, "the error replaces the example line")
        XCTAssertFalse(app.readerLibraryButton.exists, "the reader was not pushed")
        XCTAssertTrue(app.libraryList.exists, "still on the Library")
        XCTAssertTrue(app.libraryClear.exists, "the text was kept")

        // No tap first: typing succeeds only if a failed submit left the field focused (the app
        // keeps focus on a failure). I could not rely on a supported way to read keyboard focus, so
        // this is the assertion.
        app.libraryQuery.typeText("0")
        XCTAssertTrue(app.libraryError.waitForNonExistence(timeout: 10), "the next edit clears the error")
        XCTAssertTrue(app.libraryHint.waitForExistence(timeout: 5))
    }

    /// Both modes. A division that does not exist is refused whatever the build: `juz 31`.
    func testAnUnknownDivisionIsRefused() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah)
        waitForLibrary(app)

        app.typeInLibraryField("juz 31", submit: true)
        XCTAssertTrue(app.libraryError.waitForExistence(timeout: 10), "the refusal")
        XCTAssertFalse(app.readerLibraryButton.exists, "the reader was not pushed")
    }

    /// Both modes. Go is not offered on an empty field, is disabled on blank text, and does what
    /// Return does on an address.
    func testGoButtonDoesWhatReturnDoes() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, ["-quranMode", "separated"])
        waitForLibrary(app)
        XCTAssertFalse(app.libraryGo.exists, "no Go on an empty field")

        app.typeInLibraryField(" ")
        XCTAssertTrue(app.libraryGo.waitForExistence(timeout: 5))
        XCTAssertFalse(app.libraryGo.isEnabled, "blank text cannot be submitted")
        app.libraryClear.tapOrClick()
        XCTAssertTrue(waitForFieldText(false, in: app), "Clear empties the field")
        XCTAssertTrue(app.libraryGo.waitForNonExistence(timeout: 5))

        app.typeInLibraryField("juz 5")
        XCTAssertTrue(app.libraryGo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.libraryGo.isEnabled)
        app.libraryGo.tapOrClick()
        waitForReader(app)
    }

    /// Both modes. `kahf` leaves surah 18 alone; `zzz` shows the empty message; an address being
    /// typed (`juz 5`) filters nothing; Clear brings every row back.
    func testFilteringTheSurahList() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah)
        waitForLibrary(app)

        app.typeInLibraryField("kahf")
        XCTAssertTrue(app.surahRow(18).waitForExistence(timeout: 10), "Al-Kahf matches")
        XCTAssertEqual(visibleSurahNumbers(in: app), [18], "and is the only row")
        XCTAssertFalse(app.libraryEmpty.exists)

        app.libraryClear.tapOrClick()
        XCTAssertTrue(app.surahRow(1).waitForExistence(timeout: 10), "Clear brings every row back")
        XCTAssertGreaterThan(visibleSurahNumbers(in: app).count, 1)

        app.libraryQuery.tapOrClick()
        app.libraryQuery.typeText("zzz")
        XCTAssertTrue(app.libraryEmpty.waitForExistence(timeout: 10), "no surah matches")
        app.libraryClear.tapOrClick()
        XCTAssertTrue(app.libraryEmpty.waitForNonExistence(timeout: 10))

        app.libraryQuery.tapOrClick()
        app.libraryQuery.typeText("juz 5")
        XCTAssertTrue(waitForFieldText(true, in: app))
        XCTAssertFalse(app.libraryEmpty.exists, "an address is not a name to filter by")
        XCTAssertTrue(app.surahRow(1).exists, "the rows are still there")
    }

    /// Both modes. A name typed on the Juz tab moves to Surah; an address does not.
    func testANameMovesToTheSurahTab() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.juz)
        waitForLibrary(app)
        XCTAssertTrue(app.juzRow(1).waitForExistence(timeout: 10))

        app.typeInLibraryField("juz 5")
        XCTAssertTrue(waitForFieldText(true, in: app))
        XCTAssertTrue(app.juzRow(1).exists, "an address stays on the Juz tab")
        XCTAssertFalse(app.surahRow(1).exists)
        app.libraryClear.tapOrClick()

        app.libraryQuery.tapOrClick()
        app.libraryQuery.typeText("kahf")
        XCTAssertTrue(app.surahRow(18).waitForExistence(timeout: 10), "a name moves to Surah")
        XCTAssertTrue(app.juzRow(1).waitForNonExistence(timeout: 5), "the Juz list is gone")
    }
}
