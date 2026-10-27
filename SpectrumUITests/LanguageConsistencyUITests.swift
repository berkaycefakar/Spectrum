import XCTest

/// Proves the in-app language switch actually reaches the screen, and that nothing is left
/// behind in the other language.
///
/// The app's language is forced through `-spectrum.language`, which lands in
/// `NSArgumentDomain` and overrides the stored preference — so this runs the same on any
/// simulator rather than depending on the device language.
///
/// Both halves of the UI are checked on purpose, because they resolve differently and have
/// broken independently: the landing copy is `Text(LocalizedStringKey)` and follows the
/// environment locale, while the auth field placeholders are `String(localized:)` and only
/// follow the choice because the bundle is passed at the call site.
final class LanguageConsistencyUITests: XCTestCase {

    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-spectrum.language", language]
        app.launch()
        return app
    }

    @MainActor
    func testTurkishIsAppliedEndToEnd() {
        let app = launch(language: "turkish")

        let getStarted = app.buttons["Başla"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 25),
                      "Landing screen is not Turkish. Visible: \(visibleText(app).prefix(400))")
        attach(app.screenshot(), named: "tr-01-landing")
        getStarted.tap()

        XCTAssertTrue(app.buttons["Giriş Yap"].waitForExistence(timeout: 10), "Auth screen never appeared.")
        attach(app.screenshot(), named: "tr-02-auth")

        // These three are the `String(localized:)` half.
        for label in ["E-posta", "Şifre", "Şifreni mi unuttun?"] {
            XCTAssertTrue(app.descendants(matching: .any)[label].exists,
                          "Expected Turkish “\(label)”. Visible: \(visibleText(app).prefix(500))")
        }

        let english = ["Email", "Password", "Forgot password?", "Log In", "Sign Up", "Get Started"]
        let visible = Set(visibleText(app))
        for word in english {
            XCTAssertFalse(visible.contains(word), "“\(word)” is still English.")
        }
    }

    @MainActor
    func testEnglishIsAppliedEndToEnd() {
        let app = launch(language: "english")

        let getStarted = app.buttons["Get Started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 25),
                      "Landing screen is not English. Visible: \(visibleText(app).prefix(400))")
        getStarted.tap()

        XCTAssertTrue(app.buttons["Log In"].waitForExistence(timeout: 10), "Auth screen never appeared.")
        attach(app.screenshot(), named: "en-02-auth")

        for label in ["Email", "Password", "Forgot password?"] {
            XCTAssertTrue(app.descendants(matching: .any)[label].exists,
                          "Expected English “\(label)”. Visible: \(visibleText(app).prefix(500))")
        }

        let turkish = ["E-posta", "Şifre", "Giriş Yap", "Başla"]
        let visible = Set(visibleText(app))
        for word in turkish {
            XCTAssertFalse(visible.contains(word), "“\(word)” is still Turkish.")
        }
    }

    private func visibleText(_ app: XCUIApplication) -> [String] {
        (app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex
         + app.textFields.allElementsBoundByIndex + app.secureTextFields.allElementsBoundByIndex)
            .map(\.label)
            .filter { !$0.isEmpty }
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
