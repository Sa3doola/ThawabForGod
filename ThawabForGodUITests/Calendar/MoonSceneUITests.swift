//
//  MoonSceneUITests.swift
//  ThawabForGodUITests
//
//  Home → the Islamic calendar card → Moon details → "Explore the 3D moon" → the 3D moon screen.
//
//  Reached through the UI rather than a link: a `noor://` URL opened from a test is gated behind
//  the system's "Open in Noor?" prompt on iOS, and the path through the screens is the thing this
//  test is for. Matched on accessibility identifiers only, so the language does not matter.
//

import XCTest

final class MoonSceneUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Scrolls until `element` exists, up to a handful of swipes.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        #if os(iOS)
        for _ in 0..<8 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
        #endif
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) should be reachable")
    }

    @MainActor
    func testThePillOpensTheThreeDimensionalMoon() throws {
        let app = XCUIApplication()
        app.launchPlatformLibrary()

        selectSection(.home, in: app)

        let card = app.element(id: "home.islamicCalendar")
        reveal(card, in: app)
        card.tapOrClick()

        let details = app.element(id: "calendar.moonDetails")
        reveal(details, in: app)
        details.tapOrClick()

        let pill = app.element(id: "moon.explore3D")
        XCTAssertTrue(pill.waitForExistence(timeout: 10), "the moon screen has the 3D pill")
        pill.tapOrClick()

        XCTAssertTrue(app.element(id: "moon.scene").waitForExistence(timeout: 10), "the 3D moon screen is up")
        XCTAssertTrue(app.element(id: "moon.scene.reset").exists, "it has a reset control")
    }
}
