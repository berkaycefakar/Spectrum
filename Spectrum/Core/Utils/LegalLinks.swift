import Foundation

/// The three URLs Apple requires a UGC app to publish, in one place.
///
/// Guideline 1.2 wants an agreed-to EULA with a stated zero-tolerance policy for objectionable
/// content, and App Store Connect separately requires a live privacy policy and support page.
/// The pages themselves live in `docs/` at the repo root and are served by GitHub Pages —
/// update both if the hosting ever moves.
enum LegalLinks {
    static let terms = URL(string: "https://berkaycefakar.github.io/Spectrum/terms.html")!
    static let privacy = URL(string: "https://berkaycefakar.github.io/Spectrum/privacy.html")!
    static let support = URL(string: "https://berkaycefakar.github.io/Spectrum/support.html")!
}
