import Foundation

/// Recognises what a `spectrum://auth-callback` link was actually for.
///
/// Supabase's `.passwordRecovery` auth event is **not** reliable on its own here: the SDK only
/// emits it from the implicit-flow handler, and this project runs the default PKCE flow, where
/// the callback is exchanged for a session and reported as a plain `.signedIn`. So a recovery
/// link would silently drop the user into the app already logged in, with no way to actually
/// change the password it was sent for.
///
/// Reading the URL ourselves covers both flows; the event listener stays as a second signal.
enum AuthDeepLink {
    /// True when this callback came from a "reset your password" email.
    static func isPasswordRecovery(_ url: URL) -> Bool {
        // Supabase puts parameters in the query for PKCE and in the fragment for implicit,
        // so both have to be inspected.
        parameters(from: url)["type"] == "recovery"
    }

    static func parameters(from url: URL) -> [String: String] {
        var result: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                result[item.name] = item.value
            }

            // The fragment is a query string in its own right ("#access_token=…&type=recovery").
            if let fragment = components.fragment, !fragment.isEmpty {
                for pair in fragment.split(separator: "&") {
                    let parts = pair.split(separator: "=", maxSplits: 1)
                    guard parts.count == 2 else { continue }
                    let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                    let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                    result[key] = value
                }
            }
        }

        return result
    }
}
