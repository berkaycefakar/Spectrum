import Foundation

/// Turns Supabase / URLSession errors into something a person can act on.
///
/// The auth screen used to print `error.localizedDescription` straight through, which meant
/// the user got strings like "Invalid login credentials" or, worse, a raw URLSession failure —
/// technically accurate, but it never told them *what to do next*.
enum AuthErrorMessage {
    static func friendly(_ error: Error) -> String {
        let nsError = error as NSError

        // Offline / timeout / DNS — never the user's fault, and no amount of retyping helps.
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "You appear to be offline. Check your connection and try again."
            case NSURLErrorTimedOut:
                return "The server took too long to respond. Try again in a moment."
            default:
                return "Couldn't reach Spectrum. Check your connection and try again."
            }
        }

        let raw = error.localizedDescription.lowercased()

        if raw.contains("invalid login credentials") || raw.contains("invalid_credentials") {
            return "Wrong email or password."
        }
        if raw.contains("email not confirmed") || raw.contains("email_not_confirmed") {
            return "Confirm your email first — check your inbox for the link we sent."
        }
        if raw.contains("already registered") || raw.contains("user_already_exists") {
            return "An account with this email already exists. Try logging in instead."
        }
        if raw.contains("duplicate key") || raw.contains("profiles_username_key") {
            return "That username is taken. Pick another one."
        }
        if raw.contains("password should be at least") || raw.contains("weak_password") {
            return "Your password is too short — use at least 6 characters."
        }
        if raw.contains("unable to validate email") || raw.contains("invalid format") || raw.contains("email_address_invalid") {
            return "That email address doesn't look right."
        }
        if raw.contains("rate limit") || raw.contains("too many requests") || raw.contains("over_email_send_rate_limit") {
            return "Too many attempts. Wait a minute and try again."
        }
        if raw.contains("cancel") {
            // ASWebAuthenticationSession / Sign in with Apple when the user backs out.
            return ""
        }

        // Anything unrecognised still reaches the user — a silent failure is worse than an
        // ugly one, and it's the only clue either of us gets.
        return error.localizedDescription
    }

    // MARK: - Client-side validation
    //
    // Catching these before the round-trip means the common mistakes answer instantly instead
    // of after a network call.

    static func validate(email: String, password: String, username: String?) -> String? {
        let email = email.trimmingCharacters(in: .whitespaces)

        if email.isEmpty { return "Enter your email address." }
        if !isPlausibleEmail(email) { return "That email address doesn't look right." }
        if password.isEmpty { return "Enter your password." }

        if let username {
            let trimmed = username.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "Pick a username." }
            if trimmed.count < 3 { return "Your username needs at least 3 characters." }
            if password.count < 6 { return "Use a password of at least 6 characters." }
        }

        return nil
    }

    /// Deliberately loose: the server is the real authority, this only catches typos like a
    /// missing "@" or a trailing dot.
    static func isPlausibleEmail(_ email: String) -> Bool {
        guard let atIndex = email.firstIndex(of: "@"), email.firstIndex(of: " ") == nil else { return false }
        let local = email[email.startIndex..<atIndex]
        let domain = email[email.index(after: atIndex)...]
        guard !local.isEmpty, domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return false }
        return domain.split(separator: ".").allSatisfy { !$0.isEmpty }
    }
}
