//
//  QuranSectionSwitchTests.swift
//  ThawabForGodUITests
//
//  M8-B1: leaving the Quran section with the reader pushed must never crash, in the tab bar
//  (compact width) or the sidebar (regular width, Mac), and the reader must still be there when the
//  reader comes back. A crash fails the test: XCTest reports the app as terminated.
//

import XCTest

final class QuranSectionSwitchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The five sections, in `AppTab.visible` order: that order is the tab bar's button order, and
    /// the raw value is the sidebar row's identifier suffix ("app.sidebar.<raw>").
    private enum Section: String {
        case home, quran, hadith, adhkar, settings

        var index: Int {
            switch self {
            case .home: 0
            case .quran: 1
            case .hadith: 2
            case .adhkar: 3
            case .settings: 4
            }
        }
    }

    @MainActor
    private func select(_ section: Section, in app: XCUIApplication) {
        if app.appTabBar.waitForExistence(timeout: 2) {
            selectTab(app.appTabBar.buttons.element(boundBy: section.index))
        } else if !app.element(id: "app.sidebar.\(section.rawValue)").waitForExistence(timeout: 3) {
            // A compact window in landscape (the Duo) draws the tab bar down the side, where it is
            // not found as a tab bar; its buttons are still labelled with the section's title.
            let button = app.buttons[section.rawValue.capitalized].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), "the tab button for \(section.rawValue)")
            selectTab(button)
        } else {
            let row = app.element(id: "app.sidebar.\(section.rawValue)")
            // A tap during the previous switch's transition can be dropped, so retry until the
            // row reports itself selected. (The Mac's outline list does not report selection on the
            // label: there the later checks on what is on screen are the assertion.)
            #if os(iOS)
            for _ in 0..<3 {
                row.tapOrClick()
                let selected = NSPredicate(format: "isSelected == true")
                let done = XCTNSPredicateExpectation(predicate: selected, object: row)
                if XCTWaiter().wait(for: [done], timeout: 3) == .completed { break }
            }
            XCTAssertTrue(row.isSelected, "the \(section.rawValue) section is selected")
            #else
            row.tapOrClick()
            #endif
        }
    }

    /// Opens the first Hadith collection (Sahih al-Bukhari), by its row's identifier.
    @MainActor
    private func openFirstHadithCollection(in app: XCUIApplication) {
        let row = app.element(id: "hadith.collection.bukhari")
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the Hadith collection row")
        row.tapOrClick()
    }

    @MainActor
    func testSwitchingSectionsWithTheReaderOpen() throws {
        #if os(iOS)
        // Landscape keeps the iPad's sidebar on screen; portrait collapses it behind a button.
        XCUIDevice.shared.orientation = .landscapeLeft
        #endif
        let app = XCUIApplication()
        app.launchQuran(["-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)

        for round in 1...5 {
            if !TestPlatform.isMac {
                select(.settings, in: app)
            }
            select(.home, in: app)
            select(.hadith, in: app)

            if round == 3 {
                // Push a [HadithRoute], then cross to the Quran and back: the Hadith/Quran pair.
                openFirstHadithCollection(in: app)
                select(.quran, in: app)
                waitForReader(app)
                select(.hadith, in: app)
            }

            select(.adhkar, in: app)
            select(.quran, in: app)
            // The reader is still pushed, not the Library.
            if !app.readerLibraryButton.waitForExistence(timeout: 20) {
                let bars = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
                XCTFail("round \(round): reader gone after Adhkar -> Quran; bars \(bars); selected quran row: \(app.element(id: "app.sidebar.quran").isSelected)")
                return
            }
            waitForReader(app)
        }
    }
}
