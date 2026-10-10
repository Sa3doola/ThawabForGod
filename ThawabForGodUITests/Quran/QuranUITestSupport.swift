//
//  QuranUITestSupport.swift
//  ThawabForGodUITests
//
//  Helpers for the Quran tab's UI tests, adapted from the Mushaf project's `ToolbarActions.swift`.
//
//  How a launch works. The DEBUG `-quran…` options bypass onboarding and select the Quran tab, but
//  only when they name a reader target (`-quranPage`, `-quranSurah`), so every launch below passes
//  one. The path then starts as `[.reader]`; a test that wants the Library taps Library.
//
//  What is matched on. Controls by `accessibilityIdentifier` only (the toolbar's labels are being
//  moved to L10nKeys). Two things have no identifier, by design (the note forbids one on a
//  container, since it would be inherited by the per-ayah elements), so they are matched on the
//  English text the code produces, with the language pinned to English at launch:
//    - the Mushaf page footer, `quran_page_footer` = "Juz %1$@ · Page %2$@": text ending in
//      "Page <n>" (and, for "any page", containing "Page");
//    - an ayah, in both modes, an accessibility button labelled `quran_surah_ayah` =
//      "%1$@, ayah %2$@": label containing ", ayah ". A Mushaf page exposes ayahs the same way, so
//      the *footer* is what tells Mushaf from separated, never an ayah.
//

import XCTest

// MARK: - Launching

extension XCUIApplication {
    /// Launches with the reset and follow-system options, English, and `options` (which must name a
    /// reader target: see the file header). On the Mac, without the windows of an earlier session.
    func launchQuran(_ options: [String]) {
        launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-quranResetSettings", "YES", "-quranFollowSystem", "NO",
        ] + options
        #if os(macOS)
        launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        #else
        // Set, never assumed: in landscape an iPhone draws the scrolling layout, with no page footer.
        // iPad is left alone; a flow that needs an orientation sets it itself.
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .portrait
        }
        #endif
        launch()
    }

    /// The element that carries a screen's title: the navigation bar's text on iOS, a static text
    /// in the window on the Mac.
    func titleText(_ title: String) -> XCUIElement {
        #if os(macOS)
        staticTexts.matching(textPredicate("==", title)).firstMatch
        #else
        navigationBars.staticTexts[title]
        #endif
    }
}

// MARK: - Tapping

extension XCUIElement {
    /// `tap()` on iOS, `click()` on the Mac.
    func tapOrClick() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }

    /// Taps an ayah's element inside the middle of the page, where a reader would. On iPhone the
    /// outer 15% of a page turns it, and a short ayah's element can be centred there.
    func tapInText(of app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let band = CGRect(x: window.minX + window.width * 0.2, y: frame.minY, width: window.width * 0.6, height: frame.height)
        let target = frame.intersection(band)
        let point = target.isNull || target.isEmpty ? CGPoint(x: frame.midX, y: frame.midY) : CGPoint(x: target.midX, y: target.midY)
        // From the window's corner: on the Mac the application element has no frame.
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - window.minX, dy: point.y - window.minY)).tapOrClick()
    }

    /// Taps in the middle of the page but outside any ayah's text: a point of the window that is
    /// not inside the frame of any of `ayahs`, in the horizontal middle band, searched downwards.
    /// Falls back to the element's own centre (a footer or header is outside the text by itself).
    func tapOutsideText(of app: XCUIApplication, avoiding ayahs: [XCUIElement]) {
        let window = app.windows.firstMatch.frame
        let frames = ayahs.filter(\.exists).map(\.frame)
        let x = window.midX
        var y = window.minY + window.height * 0.15
        while y < window.maxY - window.height * 0.1 {
            let point = CGPoint(x: x, y: y)
            if !frames.contains(where: { $0.insetBy(dx: -4, dy: -4).contains(point) }) {
                app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: point.x - window.minX, dy: point.y - window.minY)).tapOrClick()
                return
            }
            y += 12
        }
        tapOrClick()
    }
}

extension XCUICoordinate {
    func tapOrClick() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}

// MARK: - Elements

extension XCUIApplication {
    /// Anything with this identifier, whatever its element type.
    func element(id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }

    var libraryList: XCUIElement { element(id: "quran.library.list") }
    func surahRow(_ number: Int) -> XCUIElement { element(id: "quran.library.surah.\(number)") }
    var readerLibraryButton: XCUIElement { element(id: "quran.reader.library") }
    var readerModeToggle: XCUIElement { element(id: "quran.reader.modeToggle") }
    var readerLoading: XCUIElement { element(id: "quran.reader.loading") }
    var readerRetry: XCUIElement { element(id: "quran.reader.retry") }

    /// The footer of Mushaf page `number`: text ending in "Page <n>". A static text's string is its
    /// label on iOS and its value on the Mac.
    func pageFooter(_ number: Int) -> XCUIElement {
        staticTexts.matching(textPredicate("ENDSWITH", "Page \(number)")).firstMatch
    }

    /// Any page's footer: only a Mushaf page has one.
    var anyPageFooter: XCUIElement {
        staticTexts.matching(textPredicate("CONTAINS", "Page ")).firstMatch
    }

    /// The accessibility buttons that are ayahs, in either mode (see the file header).
    var ayahElements: XCUIElementQuery {
        buttons.matching(NSPredicate(format: "label CONTAINS %@", ", ayah "))
    }

    /// The ayah element with this number, whatever the surah: the label ends with ", ayah <n>".
    func ayahElement(verse: Int) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", ayah \(verse)")).firstMatch
    }

    /// The tab bar: iPhone (compact width). The sidebar arrangement has none.
    var appTabBar: XCUIElement { tabBars.firstMatch }
}

/// Matches a static text by its string on either platform (label on iOS, value on the Mac).
func textPredicate(_ format: String, _ argument: String) -> NSPredicate {
    NSPredicate(format: "label \(format) %@ OR value \(format) %@", argument, argument)
}

extension XCUIElement {
    /// A static text's string: its label on iOS, its value on the Mac.
    var text: String { label.isEmpty ? (value as? String ?? "") : label }
}

// MARK: - Platforms

enum TestPlatform {
    static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    static var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// A short name for screenshot files: the simulator's device name, or "mac".
    static var deviceName: String {
        #if os(macOS)
        "mac"
        #else
        let raw = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model
        return raw.lowercased().replacingOccurrences(of: " ", with: "-")
        #endif
    }
}

// MARK: - Waiting and state

/// The reader has a navigation bar: the Library button exists. Test-case helpers.
extension XCTestCase {
    /// Waits until the reader has loaded: its Library button is there and its progress view is gone.
    /// Fails if the failure screen shows instead.
    @MainActor
    func waitForReader(_ app: XCUIApplication, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.readerLibraryButton.waitForExistence(timeout: timeout), "the reader's Library button", file: file, line: line)
        XCTAssertTrue(app.readerLoading.waitForNonExistence(timeout: timeout), "the reader finished loading", file: file, line: line)
        XCTAssertFalse(app.readerRetry.exists, "the Quran data loaded (no Try again)", file: file, line: line)
    }

    /// Skips unless this build has Mushaf pages: the mode toggle exists once the reader has loaded.
    @MainActor
    func requireMushafPages(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        waitForReader(app, file: file, line: line)
        // Loaded content and the toggle appear in one update; a short wait covers the render.
        try XCTSkipUnless(
            app.readerModeToggle.waitForExistence(timeout: 2),
            "This build has no Mushaf pages (public data): the mode toggle does not exist."
        )
    }

    /// Whether `element` exists and its centre is inside the window (a pager keeps neighbouring
    /// pages in the tree). Waits with an expectation, never a sleep.
    @MainActor
    func waitUntilOnScreen(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { _, _ in
            let window = app.windows.firstMatch
            return element.exists && window.frame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Whether `element` exists with its centre inside the window, right now.
    @MainActor
    func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        element.exists && app.windows.firstMatch.frame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
    }

    /// Selects a tab-bar button and verifies it took: tap, wait for `isSelected`, and if it did not
    /// become selected (and still is not on a last look), tap once more and wait again.
    ///
    /// The second tap exists because another screen may be showing a popover (Home's TipKit tips are
    /// one on a fresh simulator), and a popover takes the first tap to dismiss itself.
    @MainActor
    func selectTab(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        func becomesSelected() -> Bool {
            let predicate = NSPredicate(format: "isSelected == true")
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
            return XCTWaiter().wait(for: [expectation], timeout: 4) == .completed
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the tab button exists", file: file, line: line)
        button.tapOrClick()
        if becomesSelected() { return }
        // Re-check before the second tap: a tap on a tab that is already selected pops its stack, so
        // if the first tap landed late the second must not be sent.
        if button.isSelected { return }
        button.tapOrClick()
        XCTAssertTrue(becomesSelected(), "the tab '\(button.label)' is selected after two taps", file: file, line: line)
    }

    /// The text of the Mushaf footer that is on screen (the pager keeps neighbouring pages in the
    /// tree), or `nil` when none is.
    @MainActor
    func onScreenFooterText(in app: XCUIApplication) -> String? {
        let window = app.windows.firstMatch.frame
        let footers = app.staticTexts.matching(textPredicate("CONTAINS", "Page "))
        for index in 0..<footers.count {
            let footer = footers.element(boundBy: index)
            if footer.exists, window.contains(CGPoint(x: footer.frame.midX, y: footer.frame.midY)) { return footer.text }
        }
        return nil
    }

    /// Waits until some page footer is on screen. Not `waitUntilOnScreen(anyPageFooter)`: the pager
    /// keeps its neighbouring pages in the hierarchy, so the first footer the query finds may belong
    /// to a page that is off screen and never comes on.
    @MainActor
    func waitForOnScreenFooter(in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { [self] _, _ in onScreenFooterText(in: app) != nil }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The labels of the ayah elements whose centres are inside the window.
    @MainActor
    func onScreenAyahLabels(in app: XCUIApplication) -> Set<String> {
        var labels = Set<String>()
        let ayahs = app.ayahElements
        for index in 0..<ayahs.count {
            let ayah = ayahs.element(boundBy: index)
            if isOnScreen(ayah, in: app) { labels.insert(ayah.label) }
        }
        return labels
    }

    /// Waits until the on-screen footer's text is no longer `text` (and some footer is on screen).
    @MainActor
    func waitForFooterToChange(from text: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { [self] _, _ in
            if let now = onScreenFooterText(in: app) { return now != text }
            return false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Turns one Mushaf page the way a reader does, on iPhone and iPad alike, and returns once the
    /// on-screen footer has changed (false if it never did). The pager is right-to-left, so "next"
    /// is a tap on the left edge on iPhone (as `QuranImmersiveTests` established; the edge zones are
    /// iPhone only) and a swipe from left to right elsewhere. If the first direction changes nothing
    /// the opposite one is tried: the test only needs the place to differ, not which way it went.
    @MainActor
    func turnOnePage(in app: XCUIApplication) -> Bool {
        guard let start = onScreenFooterText(in: app) else { return false }
        let window = app.windows.firstMatch
        func turn(next: Bool) {
            if TestPlatform.isPhone {
                window.coordinate(withNormalizedOffset: CGVector(dx: next ? 0.05 : 0.95, dy: 0.55)).tapOrClick()
            } else {
                #if os(macOS)
                // A drag across the middle of the window: left-to-right goes to the next page.
                let from = window.coordinate(withNormalizedOffset: CGVector(dx: next ? 0.3 : 0.7, dy: 0.5))
                let to = window.coordinate(withNormalizedOffset: CGVector(dx: next ? 0.7 : 0.3, dy: 0.5))
                from.click(forDuration: 0.05, thenDragTo: to)
                #else
                // A swipe on an ayah that is on the page, not at a fraction of the window: on an iPad
                // in the sidebar arrangement the window's leading third is the sidebar, and a drag
                // that starts there never reaches the pager. Swiping right goes to the next page.
                let ayahs = app.ayahElements
                var onPage: XCUIElement = window
                for index in 0..<min(ayahs.count, 40) where isOnScreen(ayahs.element(boundBy: index), in: app) {
                    onPage = ayahs.element(boundBy: index)
                    break
                }
                if next { onPage.swipeRight() } else { onPage.swipeLeft() }
                #endif
            }
        }
        turn(next: true)
        if waitForFooterToChange(from: start, in: app, timeout: 4) { return true }
        turn(next: false)
        return waitForFooterToChange(from: start, in: app, timeout: 4)
    }

    /// The numbers of the Library's surah rows currently on screen, from their identifiers.
    @MainActor
    func visibleSurahNumbers(in app: XCUIApplication) -> [Int] {
        let window = app.windows.firstMatch.frame
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "quran.library.surah."))
        var numbers: [Int] = []
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            guard row.exists, window.intersects(row.frame),
                  let number = Int(row.identifier.dropFirst("quran.library.surah.".count)) else { continue }
            numbers.append(number)
        }
        return numbers.sorted()
    }

    /// Scrolls the Library until the row of surah `number` is hittable, swiping towards it: forward
    /// when it is past the last visible row, back when it is before the first. Bounded; on giving up
    /// it fails and says which rows were visible.
    @MainActor
    func scrollToSurahRow(_ number: Int, in app: XCUIApplication, maxScrolls: Int = 20, file: StaticString = #filePath, line: UInt = #line) {
        let list = app.libraryList
        let row = app.surahRow(number)
        var scrolls = 0
        while !(row.exists && row.isHittable) {
            let visible = visibleSurahNumbers(in: app)
            guard scrolls < maxScrolls, let first = visible.first, let last = visible.last else {
                XCTFail("could not reach surah row \(number); visible rows when giving up: \(visibleSurahNumbers(in: app))", file: file, line: line)
                return
            }
            let forward = number >= first && number <= last ? true : number > last
            #if os(macOS)
            list.scroll(byDeltaX: 0, deltaY: forward ? -300 : 300)
            #else
            if forward { list.swipeUp() } else { list.swipeDown() }
            #endif
            scrolls += 1
        }
    }
}

// MARK: - Screenshots

extension XCTestCase {
    /// Attaches a screenshot named `<device>-<screen>-<theme>` and, when the runner has
    /// `QURAN_SCREENSHOT_DIR` (pass `TEST_RUNNER_QURAN_SCREENSHOT_DIR=…/Screenshots/quran-migration/M5/M5.1`
    /// to xcodebuild), also writes `<name>.png` there. The directory is git-ignored; simulator
    /// runners share the host's file system. XCUITest cannot read a bar's colour, so these are for
    /// eyes, not assertions.
    @MainActor
    func captureScreenshot(_ app: XCUIApplication, screen: String, theme: String) {
        let name = "\(TestPlatform.deviceName)-\(screen)-\(theme)"
        let screenshot = (TestPlatform.isMac ? app.windows.firstMatch.screenshot() : app.screenshot())
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["QURAN_SCREENSHOT_DIR"], !directory.isEmpty {
            let folder = URL(fileURLWithPath: directory, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}
