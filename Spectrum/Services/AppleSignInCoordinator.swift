import AuthenticationServices
import CryptoKit
import Foundation

/// Nonce handling for Sign in with Apple.
///
/// Apple embeds a **SHA-256 hash** of the nonce in the identity token, while Supabase needs
/// the original plaintext to verify it. So the raw value is what we keep, the hash is what we
/// hand to `ASAuthorizationAppleIDRequest`, and getting these two the wrong way round is the
/// classic reason `signInWithIdToken` rejects an otherwise valid token.
enum AppleSignInNonce {
    /// A fresh random nonce. Generate one per authorization attempt — reusing it defeats the
    /// replay protection the nonce exists for.
    static func make(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                // SecRandomCopyBytes failing is not something we can paper over with a weaker
                // source: a predictable nonce silently removes the replay protection.
                fatalError("Unable to generate a secure nonce (SecRandomCopyBytes: \(status))")
            }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }

        return result
    }

    /// SHA-256, hex encoded — the form Apple expects on the request.
    static func hashed(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension ASAuthorizationAppleIDCredential {
    /// Apple returns the user's name **only on the first ever authorization** for an app.
    /// Every later sign-in has nil here, which is why we push it to the profile immediately
    /// rather than expecting to look it up again.
    var displayName: String? {
        guard let components = fullName else { return nil }
        let parts = [components.givenName, components.familyName].compactMap { $0 }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return joined.isEmpty ? nil : joined
    }

    var identityTokenString: String? {
        identityToken.flatMap { String(data: $0, encoding: .utf8) }
    }
}
