import Foundation

/// Diagnostic logging that compiles away outside Debug builds.
///
/// The service layer prints a fair amount of context when a request fails — including
/// account-deletion and sign-out failures, which name the operation that went wrong. Shipping
/// those to the device console in Release tells anyone with a cable more about a user's
/// session than they need to know, and costs string interpolation on every failure path.
func debugLog(_ items: Any..., separator: String = " ") {
    #if DEBUG
    print(items.map { "\($0)" }.joined(separator: separator))
    #endif
}
