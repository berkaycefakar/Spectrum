import XCTest
@testable import Spectrum

/// Pins down which mechanism covers which lookup. The two halves of the UI resolve their
/// strings differently, and getting this wrong is silent — the screen simply stays in the
/// other language.
@MainActor
final class LanguagePreferenceTests: XCTestCase {

    override func tearDown() async throws {
        LanguagePreference.shared.select(.system)
    }

    /// `String(localized:)` reads its bundle directly and never sees SwiftUI's environment, so
    /// it only follows the in-app choice when handed `appStringsBundle` at the call site.
    func testStringLocalizedFollowsTheChoiceWhenGivenTheBundle() {
        LanguagePreference.shared.select(.turkish)
        XCTAssertEqual(String(localized: "Settings", bundle: appStringsBundle), "Ayarlar")
        XCTAssertEqual(
            String(localized: "Wrong email or password.", bundle: appStringsBundle),
            "E-posta veya şifre yanlış."
        )

        LanguagePreference.shared.select(.english)
        XCTAssertEqual(String(localized: "Settings", bundle: appStringsBundle), "Settings")
    }

    /// The reason the bundle has to be passed everywhere: without it the lookup ignores the
    /// choice entirely. Swapping `Bundle.main`'s class — the usual trick for this — does not
    /// help, because modern Foundation bypasses `NSBundle.localizedString` for this call.
    /// If this ever starts failing, the explicit `bundle:` arguments can be dropped.
    func testStringLocalizedIgnoresTheChoiceWithoutTheBundle() {
        LanguagePreference.shared.select(.turkish)
        XCTAssertEqual(
            String(localized: "Settings"),
            "Settings",
            "String(localized:) picked up the in-app choice on its own — the explicit bundle may no longer be needed."
        )
    }

    /// Dates go through `Locale`, not the bundle, so they are carried separately.
    func testLocaleFollowsTheChoice() {
        LanguagePreference.shared.select(.turkish)
        XCTAssertEqual(LanguagePreference.shared.locale.identifier, "tr")

        LanguagePreference.shared.select(.english)
        XCTAssertEqual(LanguagePreference.shared.locale.identifier, "en")

        LanguagePreference.shared.select(.system)
        XCTAssertEqual(LanguagePreference.shared.locale, .autoupdatingCurrent)
    }

    /// The choice has to survive a relaunch, which is the point of storing it.
    func testChoiceIsPersisted() {
        LanguagePreference.shared.select(.turkish)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "spectrum.language"), "turkish")
    }

    /// Every language names itself, so the picker stays readable to someone who opened it
    /// because they cannot read the current one.
    func testEachLanguageIsNamedInItsOwnLanguage() {
        XCTAssertEqual(LanguagePreference.Choice.english.label, "English")
        XCTAssertEqual(LanguagePreference.Choice.turkish.label, "Türkçe")
    }
}
