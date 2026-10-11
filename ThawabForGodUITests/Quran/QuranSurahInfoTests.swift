//
//  QuranSurahInfoTests.swift
//  ThawabForGodUITests
//
//  M5.2: surah info, reached from a surah row by a trailing swipe (iOS) or the context menu (the
//  Mac, where a swipe has no equivalent). The action exists only where a surah-info pack serves the
//  interface language: English in a build that bundles the packs. `-quranData public` swaps the
//  database only, so it does not remove the pack; a build without any packs is what lacks the action.
//

import XCTest

@MainActor
final class QuranSurahInfoTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    /// Where the pack is bundled (English). Swipe (context menu on the Mac) on row 18, "Surah Info":
    /// the facts card and the text exist and the bar says the surah's name; Back is the Library on
    /// the same row. Skips when the action never appears.
    func testSurahInfoOpensAndGoesBack() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah)
        waitForLibrary(app)

        scrollToSurahRow(18, in: app)
        let row = app.surahRow(18)
        let name = surahName(ofRow: row)
        app.revealSurahInfoAction(on: row)
        try XCTSkipUnless(
            app.surahInfoAction.waitForExistence(timeout: 5),
            "No surah-info pack serves English in this build: the action is not offered."
        )
        app.surahInfoAction.tapOrClick()

        XCTAssertTrue(app.surahInfoFacts.waitForExistence(timeout: 15), "the facts card")
        XCTAssertTrue(app.titleText(name).waitForExistence(timeout: 10), "the title is \(name)")
        XCTAssertTrue(app.surahInfoText.waitForExistence(timeout: 20), "the introduction")
        XCTAssertFalse(app.libraryQuery.exists, "the Library is covered")

        app.tapBack()
        XCTAssertTrue(app.libraryList.waitForExistence(timeout: 10), "Back is the Library")
        XCTAssertTrue(app.surahInfoFacts.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.surahRow(18).waitForExistence(timeout: 10), "on the Surah tab, where it was")
    }

    /// A build with no packs (public data bundled): a surah row offers no such action, by swipe or by
    /// a long press. Skips where the build has pages (the full build bundles the packs, and
    /// `-quranData public` does not remove them).
    func testPublicBuildOffersNoSurahInfo() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah)
        waitForLibrary(app)
        try XCTSkipIf(app.libraryHasPages, "The full build bundles the surah-info pack; run on a public-only bundle.")
        assertNoSurahInfoAction(in: app)
    }

    /// Both data modes. In an Arabic interface no pack serves the language, so no action is offered.
    func testSurahInfoIsAbsentInArabic() throws {
        let app = XCUIApplication()
        app.launchQuranLibrary(.surah, language: .arabic)
        waitForLibrary(app)
        assertNoSurahInfoAction(in: app)
    }

    /// Each probe gesture on row 1 (both swipe directions on iOS, the context click on the Mac; no
    /// long press, which would just press the row's button): none produces the action. Before each
    /// gesture the row must be on screen; if a gesture opened the reader instead of revealing
    /// anything, go back and carry on, since that is the row being activated, not an action.
    private func assertNoSurahInfoAction(in app: XCUIApplication) {
        for index in 0..<app.surahInfoProbeCount {
            if app.readerLibraryButton.exists {
                app.readerLibraryButton.tapOrClick()
                waitForLibrary(app)
            }
            XCTAssertTrue(waitUntilOnScreen(app.surahRow(1), in: app), "row 1 is on screen before probe \(index)")
            app.performSurahInfoProbe(index, on: app.surahRow(1))
            XCTAssertFalse(app.surahInfoAction.waitForExistence(timeout: 2), "no surah-info action after probe \(index)")
        }
    }
}
