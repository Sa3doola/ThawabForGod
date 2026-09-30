// TEMPORARY — verification screenshots for the typography slice. Not to be committed.

import XCTest

final class ScreenshotTourTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testTour() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        shot("home")

        app.open(URL(string: "noor://quran")!)
        sleep(2)
        shot("quran-list")

        for (name, tag) in [("الفاتحة", "s001"), ("البقرة", "s002"), ("التوبة", "s009"), ("الأحزاب", "s033"), ("الناس", "s114")] {
            openSurah(app, name)
            sleep(2)
            shot("reader-\(tag)")
            if tag == "s002" {
                app.swipeUp()
                sleep(1)
                shot("reader-\(tag)-scrolled")
                openSettings(app)
            }
            back(app)
        }
    }

    @MainActor
    private func openSurah(_ app: XCUIApplication, _ arabicName: String) {
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", arabicName)).firstMatch
        var tries = 0
        while !(row.exists && row.isHittable) && tries < 40 {
            app.swipeUp()
            tries += 1
        }
        row.tap()
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        let button = app.buttons.matching(
            NSPredicate(format: "label == 'Reading Options' OR label == 'خيارات القراءة'")
        ).firstMatch
        button.tap()
        sleep(2)
        shot("settings-medium")
        app.swipeUp()
        sleep(1)
        shot("settings-large")
        app.swipeUp()
        sleep(1)
        shot("settings-large-scrolled")
        let done = app.buttons.matching(NSPredicate(format: "label == 'Done' OR label == 'تم'")).firstMatch
        if done.exists { done.tap() }
        sleep(1)
    }

    @MainActor
    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        // Scroll the list back to the top for the next search.
        for _ in 0..<15 { app.swipeDown(velocity: .fast) }
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
