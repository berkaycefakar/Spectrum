import XCTest

/// Proves a Turkish phone gets a Turkish screen, with nothing English left between the lines.
///
/// Spectrum ships English and Turkish through `Localizable.xcstrings`, and the gap that made
/// this test necessary was a partial one: strings written as plain `String` rather than
/// `LocalizedStringKey` were never extracted, so they stayed English next to translated
/// headings. This only means anything on a Turkish simulator —
///
///     xcrun simctl spawn <udid> defaults write "Apple Global Domain" AppleLanguages -array tr en
///
/// — so it skips itself rather than passing vacuously on an English one.
final class LanguageConsistencyUITests: XCTestCase {

    @MainActor
    func testAuthFlowIsTurkishOnATurkishDevice() throws {
        let deviceLanguage = Locale.preferredLanguages.first ?? "en"
        try XCTSkipUnless(
            deviceLanguage.hasPrefix("tr"),
            "Only meaningful on a Turkish device; this one is \(deviceLanguage)."
        )

        let app = XCUIApplication()
        app.launch()

        let getStarted = app.buttons["Başla"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 20), "Landing screen never appeared in Turkish.")
        attach(app.screenshot(), named: "01-landing")
        getStarted.tap()

        XCTAssertTrue(app.buttons["Giriş Yap"].waitForExistence(timeout: 10), "Auth screen never appeared.")
        attach(app.screenshot(), named: "02-auth")

        // Placeholders and the reset link: all three were plain `String`s until this pass, so
        // they are the regression this test exists to catch.
        for label in ["E-posta", "Şifre", "Şifreni mi unuttun?"] {
            XCTAssertTrue(
                app.descendants(matching: .any)[label].exists,
                "Expected the Turkish “\(label)”. Visible: \(visibleText(app).prefix(600))"
            )
        }

        // Nothing on this screen should still be in English.
        let english = ["Email", "Password", "Forgot password?", "Log In", "Sign Up", "Get Started"]
        let visible = Set(visibleText(app))
        for word in english {
            XCTAssertFalse(visible.contains(word), "“\(word)” is still English on the auth screen.")
        }

        app.buttons["Kayıt Ol"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Kullanıcı adı"].waitForExistence(timeout: 5),
                      "Sign-up username field is not translated.")
        attach(app.screenshot(), named: "03-signup")
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
