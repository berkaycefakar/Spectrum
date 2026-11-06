import XCTest

/// Store screenshots: runs the app in demo mode and attaches each main screen. Run on the
/// iPhone Pro Max simulator for 1320×2868 images; export with `xcresulttool export attachments`.
final class StoreScreenshotsUITests: XCTestCase {

    @MainActor
    func testCaptureStoreScreens() {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += ["-spectrum.language", "english", "-spectrum.demo", "YES"]
        app.launch()

        let home = app.buttons["Home"]
        XCTAssertTrue(home.waitForExistence(timeout: 30), "Not signed in or tab bar missing")
        settle(8)
        shot(app, "01-feed")

        // First feed card → its detail page.
        let firstCard = app.scrollViews.firstMatch.buttons.element(boundBy: 0)
        if firstCard.waitForExistence(timeout: 5) {
            firstCard.tap()
            settle(4)
            shot(app, "02-detail")
            let log = app.buttons["Log"].firstMatch
            if log.waitForExistence(timeout: 3) {
                log.tap()
                settle(3)
                // A ray of the prism picks the vibe; the last bar is a full five.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.40)).tap()
                settle(1)
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.61, dy: 0.715)).tap()
                settle(1)
                let field = app.textFields.firstMatch
                if field.waitForExistence(timeout: 2) {
                    field.tap()
                    field.typeText("The bridge alone. On repeat all week.")
                    app.staticTexts["Snooze"].firstMatch.tap()
                }
                settle(2)
                shot(app, "03-log")
                app.swipeDown(velocity: .fast)
                settle(2)
            }
            tab(app, "Home")
            settle(2)
        }

        tab(app, "Activity")
        settle(6)
        shot(app, "05-activity")

        tab(app, "Profile")
        settle(8)
        shot(app, "06-profile")
        app.swipeUp()
        settle(3)
        shot(app, "07-profile-stats")
        app.swipeUp()
        settle(3)
        shot(app, "08-profile-logs")
    }

    private func tab(_ app: XCUIApplication, _ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 5) { button.tap() }
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
