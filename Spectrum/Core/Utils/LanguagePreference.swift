import Foundation
import Combine

/// Where every explicit `String(localized:)` lookup reads from.
///
/// `.main` while the app follows the device. Deliberately a free function rather than a
/// property on `LanguagePreference`: it is called from nonisolated code — `SupabaseManager`
/// builds its thrown errors off the main actor — and reading it must not require hopping.
nonisolated var appStringsBundle: Bundle {
    LanguagePreference.overrideBundle ?? .main
}

/// The app's language, chosen inside the app rather than in iOS Settings.
///
/// Spectrum ships English and Turkish. Without this the language is whatever the phone is set
/// to, and there is no way to read the app in the other one — iOS does expose a per-app
/// language switch in Settings, but nobody finds it.
///
/// **The two halves resolve differently, and that is the whole design.** Verified in the
/// simulator, one case at a time:
///
/// - `Text("…")` takes a `LocalizedStringKey` and follows SwiftUI's environment locale. An
///   English phone with `\.locale` set to `tr` draws Turkish, so the root view setting
///   `\.locale` is all that half needs.
/// - `String(localized:)` does not. It reads its bundle directly and never sees the
///   environment, so it has to be handed `appStringsBundle` at the call site. Swapping
///   `Bundle.main`'s class — the usual trick — does **not** work on it either: modern
///   Foundation bypasses `NSBundle.localizedString(forKey:value:table:)` for this call, which
///   `LanguagePreferenceTests` pins down. That path covers about a third of what the user
///   reads: every error message, the tab titles, the report reasons, the vibe names.
@MainActor
final class LanguagePreference: ObservableObject {
    static let shared = LanguagePreference()

    enum Choice: String, CaseIterable, Identifiable {
        case system
        case english
        case turkish

        var id: String { rawValue }

        /// `nil` means "follow the device".
        var languageCode: String? {
            switch self {
            case .system: nil
            case .english: "en"
            case .turkish: "tr"
            }
        }

        /// Each language is named in its own language — the convention from iOS Settings to
        /// Wikipedia, and the only labelling that stays readable to someone who opened the
        /// picker *because* the current language is one they can't read.
        var label: String {
            switch self {
            case .system: String(localized: "Device language", bundle: appStringsBundle)
            case .english: "English"
            case .turkish: "Türkçe"
            }
        }
    }

    @Published private(set) var choice: Choice {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: Self.storageKey)
            Self.applyOverride(for: choice)
        }
    }

    private static let storageKey = "spectrum.language"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        let initial = stored.flatMap(Choice.init(rawValue:)) ?? .system
        choice = initial
        Self.applyOverride(for: initial)
    }

    func select(_ newChoice: Choice) {
        guard newChoice != choice else { return }
        choice = newChoice
    }

    /// The bundle for the current choice, for callers that have one to hand.
    var bundle: Bundle { appStringsBundle }

    /// Formatting locale. Dates and numbers go through `Locale`, not the bundle, so they are
    /// carried separately from the string lookups.
    var locale: Locale {
        guard let code = choice.languageCode else { return .autoupdatingCurrent }
        return Locale(identifier: code)
    }

    /// The `.lproj` to read from, or nil while following the device.
    ///
    /// Read from any thread through `appStringsBundle`, written only here on the main actor.
    nonisolated(unsafe) fileprivate(set) static var overrideBundle: Bundle?

    private static func applyOverride(for choice: Choice) {
        guard
            let code = choice.languageCode,
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            overrideBundle = nil
            return
        }
        overrideBundle = bundle
    }
}
