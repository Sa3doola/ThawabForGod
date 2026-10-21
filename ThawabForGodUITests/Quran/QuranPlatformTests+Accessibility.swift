//
//  QuranPlatformTests+Accessibility.swift
//  ThawabForGodUITests
//
//  M8-C2, batch C: accessibility. The largest Dynamic Type size on an iPhone's reader, one
//  VoiceOver element per ayah in both display modes, and Apple's accessibility audit on four screens.
//
//  Audit policy (decision D2): the audit fails the test only for .elementDetection, .hitRegion,
//  .sufficientElementDescription and .trait. Every other issue (.dynamicType on the fixed-size
//  Mushaf page, .contrast on the sepia paper, ...) is attached to the result and not failed: those
//  are by design.
//

import XCTest

extension QuranPlatformTests {
    // MARK: Largest text

    /// iPhone, accessibility XXXL text: the reader still loads, the ayah is there, the Library button
    /// can be tapped and the settings sheet opens.
    @MainActor
    func testLargestTextReader() throws {
        try XCTSkipUnless(TestPlatform.isPhone, "iPhone only: the Library half is covered by testLargestAccessibilityTextSize")
        let app = XCUIApplication()
        app.launchPlatform(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                            "-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255"])
        waitForReader(app)

        XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 15), "ayah 255 is in the tree at the largest size")
        XCTAssertTrue(app.readerLibraryButton.isHittable, "the Library button is still reachable")

        app.openReaderSettings()
        XCTAssertTrue(app.element(id: "quran.settings.form").waitForExistence(timeout: 10), "the settings sheet opens at the largest size")
    }

    // MARK: VoiceOver elements

    /// The on-screen ayah elements of `surahName`, as an array (not a set) so duplicates show.
    @MainActor
    private func onScreenAyahLabelList(startingWith prefix: String, in app: XCUIApplication) -> [String] {
        var labels: [String] = []
        let ayahs = app.ayahElements
        for index in 0..<ayahs.count {
            let ayah = ayahs.element(boundBy: index)
            if isOnScreen(ayah, in: app), ayah.label.hasPrefix(prefix) { labels.append(ayah.label) }
        }
        return labels
    }

    /// Asserts that the seven ayahs of Al-Fatihah are seven distinct, non-empty elements labelled
    /// "<surah>, ayah 1" ... "<surah>, ayah 7".
    @MainActor
    private func assertOneElementPerFatihahAyah(in app: XCUIApplication, _ context: String, atLeast minimum: Int) {
        let first = app.ayahElement(verse: 1)
        XCTAssertTrue(first.waitForExistence(timeout: 15), "\(context): ayah 1 exists")
        let name = first.label.components(separatedBy: ", ayah ").first ?? ""
        XCTAssertFalse(name.isEmpty, "\(context): the label names the surah")

        let prefix = name + ", ayah "
        XCTAssertTrue(waitForDeviceCondition { self.onScreenAyahLabelList(startingWith: prefix, in: app).count >= minimum },
                      "\(context): at least \(minimum) ayahs on screen; saw \(onScreenAyahLabelList(startingWith: prefix, in: app))")
        let labels = onScreenAyahLabelList(startingWith: prefix, in: app)
        XCTAssertEqual(labels.count, Set(labels).count, "\(context): no ayah appears twice; saw \(labels)")
        // The first N ayahs, in order from the top: a phone shows only some of the seven.
        XCTAssertEqual(Set(labels), Set((1...labels.count).map { "\(name), ayah \($0)" }), "\(context): ayahs 1 to \(labels.count), none skipped")
        XCTAssertFalse(labels.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(context): no empty label")
    }

    /// Separated mode: one element per ayah, not one per word or per paragraph.
    @MainActor
    func testOneElementPerAyah() throws {
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "1"])
        waitForReader(app)
        assertOneElementPerFatihahAyah(in: app, "separated", atLeast: 3)
    }

    /// Mushaf mode (full data): page 1 is Al-Fatihah, one element per ayah again.
    @MainActor
    func testOneElementPerAyahMushaf() throws {
        let app = XCUIApplication()
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "1"])
        try requireMushafPages(app)
        assertOneElementPerFatihahAyah(in: app, "mushaf page 1", atLeast: 7)
    }

    // MARK: Audit

    /// Runs the audit on the screen in front. Issues of the four failing kinds are recorded in
    /// `failures`; everything else is attached and ignored.
    @MainActor
    private func audit(_ screen: String, in app: XCUIApplication, failures: inout [String]) throws {
        var found: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            let description = "\(screen): \(issue.compactDescription) [\(issue.detailedDescription)] on \(issue.element?.debugDescription ?? "no element")"
            #if os(iOS)
            let blocking: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
            #else
            // `.trait` is iOS-only.
            let blocking: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription]
            #endif
            // Two kinds of finding cannot be acted on and are attached instead of failing (BUGS.md B10):
            // a finding about no element at all (the audit saw text on screen it could not map to anything:
            // a manual VoiceOver check follows), and an unlabeled container (a window group, the
            // Touch Bar, an outline), which the Mac reports for every window.
            let containers: Set<XCUIElement.ElementType> = [.group, .other, .touchBar, .outline, .window, .scrollView, .splitGroup, .toolbar]
            let unactionable = issue.element == nil || issue.element.map { containers.contains($0.elementType) } == true
            if !issue.auditType.intersection(blocking).isEmpty, !unactionable {
                found.append(description)
            } else {
                let note = XCTAttachment(string: description)
                note.name = "audit-ignored-\(screen)"
                note.lifetime = .keepAlways
                self.add(note)
            }
            // Handled either way: the verdict is made once, after all four screens.
            return true
        }
        failures += found
    }

    /// Apple's accessibility audit on the Library, a Mushaf page (full only), a separated reader and
    /// an open panel.
    @MainActor
    func testAccessibilityAudit() throws {
        var failures: [String] = []
        let app = XCUIApplication()

        app.launchPlatformLibrary()
        waitForLibrary(app)
        try audit("library", in: app, failures: &failures)

        app.terminate()
        app.launchPlatform(["-quranMode", "mushaf", "-quranPage", "50"])
        waitForReader(app)
        if app.hasDisplayModeControl {
            XCTAssertTrue(waitForOnScreenFooter(in: app), "the Mushaf page drew")
            try audit("mushaf-page-50", in: app, failures: &failures)
        }

        app.terminate()
        app.launchPlatform(["-quranMode", "separated", "-quranSurah", "2", "-quranAyah", "255"])
        waitForReader(app)
        XCTAssertTrue(app.ayahElement(verse: 255).waitForExistence(timeout: 15), "ayah 255 is on screen")
        try audit("separated-2-255", in: app, failures: &failures)

        app.terminate()
        app.launchPlatform(devicePanelLaunch)
        waitForReader(app)
        XCTAssertTrue(panelArabic(in: app).waitForExistence(timeout: 15), "the panel is open")
        try audit("panel-2-255", in: app, failures: &failures)

        XCTAssertTrue(failures.isEmpty, "accessibility audit issues:\n" + failures.joined(separator: "\n"))
    }
}
