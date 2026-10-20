//
//  QuranUITestSupport.swift
//  ThawabForGodUITests
//
//  Helpers for the Quran tab's UI tests, adapted from the Mushaf project's `ToolbarActions.swift`.
//
//  How a launch works. The DEBUG `-quran…` options bypass onboarding and select the Quran tab when
//  they name a reader target (`-quranPage`, `-quranSurah`: the path then starts as `[.reader]`, and
//  a test that wants the Library taps Library) or a Library index (`-quranLibrary surah|juz|hizb|
//  page`: the path is empty and the Library is in front). `launchQuran` is the first,
//  `launchQuranLibrary` the second.
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
        launchScripted(options, language: .english)
    }

    /// Launches into the Library (no reader pushed) with `tab` selected, the reset and
    /// follow-system options, and `options` (`-quranData public`, `-quranMode …`, `-AppleInterfaceStyle
    /// Dark`, …). The orientation is set exactly as `launchQuran` sets it.
    func launchQuranLibrary(_ tab: LibraryTab = .surah, _ options: [String] = [], language: TestLanguage = .english) {
        launchScripted(["-quranLibrary", tab.rawValue] + options, language: language)
    }

    private func launchScripted(_ options: [String], language: TestLanguage) {
        launchArguments = [
            "-AppleLanguages", language.languages, "-AppleLocale", language.locale,
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

    /// Taps an ayah's element inside the middle of the page, where a reader would. (Edge zones no
    /// longer turn pages; the middle band just keeps the point on text.)
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
        // At compact width the toggle sits in the More menu, which exists only when there is a mode to switch.
        try XCTSkipUnless(
            app.readerModeToggle.waitForExistence(timeout: 2) || app.element(id: "quran.reader.more").exists,
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

    /// The page numbers whose footers are on screen, ascending: one page, or two in a spread (the
    /// pager keeps neighbouring pages in the tree, so only footers whose centre is in the window
    /// count). Parsed from "... Page <n>"; the language is pinned to English at launch.
    @MainActor
    func onScreenPageNumbers(in app: XCUIApplication) -> [Int] {
        let window = app.windows.firstMatch.frame
        let footers = app.staticTexts.matching(textPredicate("CONTAINS", "Page "))
        var pages = Set<Int>()
        for index in 0..<footers.count {
            let footer = footers.element(boundBy: index)
            guard footer.exists, window.contains(CGPoint(x: footer.frame.midX, y: footer.frame.midY)),
                  let range = footer.text.range(of: #"Page (\d+)"#, options: .regularExpression),
                  let number = Int(footer.text[range].dropFirst("Page ".count)) else { continue }
            pages.insert(number)
        }
        return pages.sorted()
    }

    /// Waits until the pages on screen are exactly `pages`.
    @MainActor
    func waitForPages(_ pages: [Int], in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { [self] _, _ in onScreenPageNumbers(in: app) == pages }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    /// Performs the gesture that turns the Mushaf pager one unit, and nothing else: it does not wait
    /// and does not check where the pager landed. The pager is right-to-left, so "next" is a swipe
    /// (a drag on the Mac) from left to right. A tap never turns a page.
    @MainActor
    func turnPage(next: Bool, in app: XCUIApplication) {
        let window = app.windows.firstMatch
        #if os(macOS)
        // A drag across the middle of the window.
        let from = window.coordinate(withNormalizedOffset: CGVector(dx: next ? 0.3 : 0.7, dy: 0.5))
        let to = window.coordinate(withNormalizedOffset: CGVector(dx: next ? 0.7 : 0.3, dy: 0.5))
        from.click(forDuration: 0.05, thenDragTo: to)
        #else
        // A swipe on an ayah that is on the page, not at a fraction of the window: on an iPad in the
        // sidebar arrangement the window's leading third is the sidebar, and a drag that starts
        // there never reaches the pager.
        let ayahs = app.ayahElements
        var onPage: XCUIElement = window
        for index in 0..<min(ayahs.count, 40) where isOnScreen(ayahs.element(boundBy: index), in: app) {
            onPage = ayahs.element(boundBy: index)
            break
        }
        // `swipeRight()` on an ayah drags across that one line, a few points: the pager reads it as a
        // tap and opens the panel. Drag across the page from the line's own height instead.
        let bounds = window.frame
        let line = onPage.frame
        let startX = min(max(line.midX, bounds.minX + bounds.width * 0.4), bounds.maxX - bounds.width * 0.1) - bounds.minX
        let y = line.midY - bounds.minY
        let dx = bounds.width * 0.3 * (next ? 1 : -1)
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: startX, dy: y))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: startX + dx, dy: y)),
                   withVelocity: .fast, thenHoldForDuration: 0)
        #endif
    }

    /// Turns one page forward by swiping and returns true only if the pager landed on exactly the
    /// next unit: the page after the last one on screen (n + 1 on a single page, n + 2 in a spread).
    /// Any other landing, or none, is false. Never taps, and never tries the other direction.
    @MainActor
    func turnOnePage(in app: XCUIApplication) -> Bool {
        let before = onScreenPageNumbers(in: app)
        guard let last = before.last else { return false }
        let expected = (0..<before.count).map { last + 1 + $0 }
        turnPage(next: true, in: app)
        return waitForPages(expected, in: app, timeout: 6)
    }

    /// Waits for the ayah panel, as a column (Close) or a sheet (Done), then dismisses it.
    @MainActor
    func dismissAyahPanel(in app: XCUIApplication, opened message: String, file: StaticString = #filePath, line: UInt = #line) {
        let close = app.element(id: "quran.panel.close")
        let done = app.element(id: "quran.panel.done")
        XCTAssertTrue(close.waitForExistence(timeout: 10) || done.waitForExistence(timeout: 2), message, file: file, line: line)
        let button = close.exists ? close : done
        button.tapOrClick()
        XCTAssertTrue(button.waitForNonExistence(timeout: 10), "the panel closed", file: file, line: line)
    }

    /// Taps the first or last word of the top line of `ayah`: its element's frame inset by 6 pt on
    /// the chosen side. The text is right-to-left and the screen coordinates are not, so the
    /// first word is at the frame's right (maxX) edge and the last word at its left (minX) edge.
    /// The frame is clipped to the window first.
    enum WordEdge { case first, last }

    @MainActor
    func tapWord(of ayah: XCUIElement, edge: WordEdge, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        let frame = ayah.frame.intersection(window)
        let x = edge == .first ? frame.maxX - 6 : frame.minX + 6
        let y = frame.minY + 6
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - window.minX, dy: y - window.minY)).tapOrClick()
    }

    /// Up to `count` ayah elements on screen whose top lies in the page's body (not under a bar),
    /// ordered top to bottom and spread through the list, so they are different lines.
    @MainActor
    func ayahsInBody(of app: XCUIApplication, count: Int) -> [XCUIElement] {
        let window = app.windows.firstMatch.frame
        var found: [(minY: CGFloat, element: XCUIElement)] = []
        let ayahs = app.ayahElements
        for index in 0..<ayahs.count {
            let ayah = ayahs.element(boundBy: index)
            guard isOnScreen(ayah, in: app),
                  ayah.frame.minY > window.minY + window.height * 0.15,
                  ayah.frame.minY < window.minY + window.height * 0.75 else { continue }
            found.append((ayah.frame.minY, ayah))
        }
        let sorted = found.sorted { $0.minY < $1.minY }.map(\.element)
        guard sorted.count > count else { return sorted }
        return (0..<count).map { sorted[$0 * (sorted.count - 1) / max(count - 1, 1)] }
    }

    /// The numbers of the Library's surah rows currently on screen, from their identifiers.
    @MainActor
    func visibleSurahNumbers(in app: XCUIApplication) -> [Int] {
        visibleLibraryNumbers(prefix: "surah", in: app)
    }

    /// The numbers of the Library's rows with identifiers `quran.library.<prefix>.<n>` that are on
    /// screen (`surah`, `juz`, `hizb`, `quarter`, `page`), sorted.
    @MainActor
    func visibleLibraryNumbers(prefix: String, in app: XCUIApplication) -> [Int] {
        let window = app.windows.firstMatch.frame
        let stem = "quran.library.\(prefix)."
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", stem))
        var numbers: [Int] = []
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            guard row.exists, window.intersects(row.frame),
                  let number = Int(row.identifier.dropFirst(stem.count)) else { continue }
            numbers.append(number)
        }
        return numbers.sorted()
    }

    /// Scrolls the Library until the row of surah `number` is hittable.
    @MainActor
    func scrollToSurahRow(_ number: Int, in app: XCUIApplication, maxScrolls: Int = 20, file: StaticString = #filePath, line: UInt = #line) {
        scrollToLibraryRow(prefix: "surah", number, in: app, maxScrolls: maxScrolls, file: file, line: line)
    }

    /// Scrolls the Library until `quran.library.<prefix>.<number>` is hittable, swiping towards it:
    /// forward when it is past the last visible row, back when it is before the first. Bounded; on
    /// giving up it fails and says which rows were visible. For the Page grid pass a generous
    /// `maxScrolls` (a screen holds a few dozen of the 604 cells).
    @MainActor
    func scrollToLibraryRow(prefix: String, _ number: Int, in app: XCUIApplication, maxScrolls: Int = 20, file: StaticString = #filePath, line: UInt = #line) {
        let list = app.libraryList
        let row = app.element(id: "quran.library.\(prefix).\(number)")
        var scrolls = 0
        while !(row.exists && row.isHittable) {
            let visible = visibleLibraryNumbers(prefix: prefix, in: app)
            guard scrolls < maxScrolls else {
                XCTFail("could not reach \(prefix) row \(number); visible rows when giving up: \(visible)", file: file, line: line)
                return
            }
            // Nothing of this kind on screen yet (only a Continue reading row): the target is below.
            let first = visible.first ?? 0
            let last = visible.last ?? 0
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

// MARK: - The Library

/// The raw values of `-quranLibrary`.
enum LibraryTab: String {
    case surah, juz, hizb, page

    /// The segment's position in `quran.library.tabs` (the titles come from the catalog, so tests
    /// select by position). Page is last, and only where the build has pages.
    var position: Int {
        switch self {
        case .surah: 0
        case .juz: 1
        case .hizb: 2
        case .page: 3
        }
    }
}

/// The interface language of a launch.
enum TestLanguage {
    case english, arabic

    var languages: String { self == .english ? "(en)" : "(ar)" }
    var locale: String { self == .english ? "en_US" : "ar_SA" }
}

extension XCUIApplication {
    var libraryQuery: XCUIElement { element(id: "quran.library.query") }
    var libraryGo: XCUIElement { element(id: "quran.library.go") }
    var libraryClear: XCUIElement { element(id: "quran.library.clear") }
    var libraryHint: XCUIElement { element(id: "quran.library.hint") }
    var libraryError: XCUIElement { element(id: "quran.library.error") }
    var libraryEmpty: XCUIElement { element(id: "quran.library.empty") }
    var libraryTabs: XCUIElement { element(id: "quran.library.tabs") }
    var libraryContinue: XCUIElement { element(id: "quran.library.continue") }
    var surahInfoAction: XCUIElement { element(id: "quran.library.surahInfo") }
    var surahInfoFacts: XCUIElement { element(id: "quran.surahInfo.facts") }
    var surahInfoText: XCUIElement { element(id: "quran.surahInfo.text") }
    func juzRow(_ number: Int) -> XCUIElement { element(id: "quran.library.juz.\(number)") }
    func hizbRow(_ number: Int) -> XCUIElement { element(id: "quran.library.hizb.\(number)") }
    func quarterRow(_ rub: Int) -> XCUIElement { element(id: "quran.library.quarter.\(rub)") }
    func pageCell(_ number: Int) -> XCUIElement { element(id: "quran.library.page.\(number)") }

    /// The segments of the picker, in order. A segment has no identifier of its own: they are the
    /// buttons (iOS) or radio buttons (the Mac) inside the element that carries `quran.library.tabs`.
    var libraryTabSegments: XCUIElementQuery {
        libraryTabs.descendants(matching: .any).matching(
            NSPredicate(format: "elementType == %d OR elementType == %d", XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.radioButton.rawValue)
        )
    }

    /// How many index tabs the build shows: 3 without pages, 4 with them.
    var libraryTabCount: Int { libraryTabSegments.count }

    /// Whether this Library has the Page tab (the build has Mushaf pages).
    var libraryHasPages: Bool { libraryTabCount == 4 }

    /// Types into the field the way a reader does: tap (click on the Mac), then type; `submit` ends
    /// with Return, which the field's `.submitLabel(.go)` turns into a go.
    func typeInLibraryField(_ text: String, submit: Bool = false) {
        libraryQuery.tapOrClick()
        libraryQuery.typeText(text + (submit ? "\n" : ""))
    }

    /// Selects the index at `position` in the picker.
    func selectLibraryTab(_ tab: LibraryTab) {
        libraryTabSegments.element(boundBy: tab.position).tapOrClick()
    }

    /// Asks for a surah row's "Surah Info" action: a trailing swipe on iOS, the context menu on the
    /// Mac (a swipe has no equivalent there). The action may not appear: that is the answer, not a
    /// failure, where no pack serves the language.
    func revealSurahInfoAction(on row: XCUIElement) {
        #if os(macOS)
        row.rightClick()
        #else
        row.swipeLeft()
        #endif
    }

    /// The gestures that would reveal a surah-info action, for the flows that assert there is none:
    /// both swipe directions on iOS (the trailing edge is the left in Arabic), the context click on
    /// the Mac. No long press: where no context menu is attached it is just a press on the row's
    /// button and opens the reader.
    var surahInfoProbeCount: Int {
        #if os(macOS)
        1
        #else
        2
        #endif
    }

    func performSurahInfoProbe(_ index: Int, on row: XCUIElement) {
        #if os(macOS)
        row.rightClick()
        #else
        if index == 0 { row.swipeLeft() } else { row.swipeRight() }
        #endif
    }

    /// Goes back one screen: the navigation bar's leading button on iOS, the toolbar's on the Mac.
    func tapBack() {
        #if os(macOS)
        toolbars.buttons.element(boundBy: 0).click()
        #else
        navigationBars.buttons.element(boundBy: 0).tap()
        #endif
    }

    /// Discloses a hizb row's quarters: a tap on the disclosure indicator, which has no identifier.
    /// It sits at the trailing edge of the row on iOS and the leading edge on the Mac, at the row's
    /// vertical middle; the row's own button covers only the label, so the point is taken from the
    /// list's frame.
    func discloseHizb(_ number: Int) {
        let row = hizbRow(number)
        let list = libraryList.frame
        #if os(macOS)
        let x = list.minX + 14
        #else
        let x = list.maxX - 24
        #endif
        let origin = windows.firstMatch.frame
        windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x - origin.minX, dy: row.frame.midY - origin.minY)).tapOrClick()
    }

    /// Whether any Library row (surah, juz, hizb, quarter, page cell or the Continue reading row)
    /// carries a label containing `text`. Matched on identifiers so the field's placeholder and the
    /// hint line are not counted.
    func libraryRowLabels(containing text: String) -> Int {
        descendants(matching: .any).matching(NSPredicate(
            format: "identifier MATCHES %@ AND label CONTAINS %@",
            "quran\\.library\\.(surah|juz|hizb|quarter|page|continue)(\\..*)?", text
        )).count
    }
}

extension XCTestCase {
    /// Waits until the Library has loaded: its picker and list are there. Fails on the failure screen.
    @MainActor
    func waitForLibrary(_ app: XCUIApplication, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.libraryTabs.waitForExistence(timeout: timeout), "the Library's picker", file: file, line: line)
        XCTAssertTrue(app.libraryList.waitForExistence(timeout: timeout), "the Library's list", file: file, line: line)
        XCTAssertFalse(app.readerRetry.exists, "the Quran data loaded (no Try again)", file: file, line: line)
    }

    /// Skips unless the Library has the Page tab (full data).
    @MainActor
    func requireLibraryPages(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        waitForLibrary(app, file: file, line: line)
        try XCTSkipUnless(app.libraryHasPages, "This build has no Mushaf pages (public data): the Library has no Page tab.")
    }

    /// Opens surah `number` from the Library and waits for the reader.
    @MainActor
    func openSurahFromLibrary(_ number: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        scrollToSurahRow(number, in: app, file: file, line: line)
        app.surahRow(number).tapOrClick()
        waitForReader(app, file: file, line: line)
    }

    /// A surah's name from a row's label ("number, name, place, ayahs…"): the second part.
    @MainActor
    func surahName(ofRow row: XCUIElement) -> String {
        let parts = row.label.components(separatedBy: ", ")
        return parts.count >= 2 ? parts[1] : row.label
    }

    /// What a juz, hizb or quarter row says it starts at: its label is "title, <name> <s>:<a>[, Page n]".
    @MainActor
    func startPlace(ofRow row: XCUIElement) -> (name: String, surah: Int, ayah: Int, page: Int?)? {
        let parts = row.label.components(separatedBy: ", ")
        guard parts.count >= 2,
              let match = parts[1].range(of: #"^(.*) (\d+):(\d+)$"#, options: .regularExpression) else { return nil }
        let reference = String(parts[1][match])
        let pieces = reference.split(separator: " ")
        guard let numbers = pieces.last?.split(separator: ":"), numbers.count == 2,
              let surah = Int(numbers[0]), let ayah = Int(numbers[1]) else { return nil }
        let name = pieces.dropLast().joined(separator: " ")
        let page = row.label.range(of: #"Page (\d+)"#, options: .regularExpression)
            .flatMap { Int(row.label[$0].dropFirst("Page ".count)) }
        return (name, surah, ayah, page)
    }

    /// Waits until something on screen carries `text` in its label or value (a bar title, an ayah).
    @MainActor
    func waitForText(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            .firstMatch.waitForExistence(timeout: timeout)
    }

    /// Waits until the field's clear button is gone (the field is empty) or there.
    @MainActor
    func waitForFieldText(_ present: Bool, in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        present ? app.libraryClear.waitForExistence(timeout: timeout) : app.libraryClear.waitForNonExistence(timeout: timeout)
    }

    /// Waits until `element` is selected (a Page cell that is the reader's current page).
    @MainActor
    func waitUntilSelected(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

// MARK: - Screenshots

extension XCTestCase {
    /// Attaches a screenshot named `<device>-<screen>-<theme>` and, when the runner has
    /// `QURAN_SCREENSHOT_DIR` (pass `TEST_RUNNER_QURAN_SCREENSHOT_DIR=…/Screenshots/quran-migration/M5/<task>`
    /// to xcodebuild; M5.2's is `M5/M5.2`), also writes `<name>.png` there. The directory is git-ignored; simulator
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
