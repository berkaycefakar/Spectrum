import Combine
import SwiftUI
// `User.id` lives in the Auth module; without this the property is invisible here.
import Supabase

/// Drives the dot on the Activity tab.
///
/// Spectrum has no push notifications — that needs an APNs key and a server that reacts to
/// database writes, neither of which exists yet. What it can do without any of that is stop
/// hiding the fact that something happened: if somebody followed you or logged a record while
/// the app was closed, the tab says so the next time you open it.
///
/// "Seen" is stored per user in `UserDefaults`, not on the server. It is a read marker, not
/// data worth syncing, and keying it by user id means signing into a second account on the
/// same phone doesn't inherit the first one's state.
@MainActor
final class ActivityBadgeStore: ObservableObject {
    static let shared = ActivityBadgeStore()

    /// True when the newest activity is newer than the last time the tab was opened.
    @Published private(set) var hasUnseen = false

    private var userId: UUID?
    private var latest: Date?
    /// Guards against the overlapping refreshes that a tab switch plus a foreground event
    /// would otherwise produce.
    private var isRefreshing = false

    private init() {}

    private func seenKey(for userId: UUID) -> String {
        "activity.lastSeen.\(userId.uuidString)"
    }

    private func lastSeen(for userId: UUID) -> Date? {
        let stored = UserDefaults.standard.double(forKey: seenKey(for: userId))
        // 0 means "never recorded" — a genuine 1970 timestamp isn't a case worth handling.
        return stored == 0 ? nil : Date(timeIntervalSince1970: stored)
    }

    /// Checks the server for anything newer than the read marker.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let user = try? await SupabaseManager.shared.getCurrentUser() else {
            userId = nil
            latest = nil
            hasUnseen = false
            return
        }

        userId = user.id
        let newest = await SupabaseManager.shared.latestActivityTimestamp(userId: user.id)
        latest = newest

        guard let newest else {
            hasUnseen = false
            return
        }

        // No marker yet means the user has never opened the tab. Showing a dot for a feed
        // they've never seen is correct — that is exactly the thing they haven't seen.
        guard let seen = lastSeen(for: user.id) else {
            hasUnseen = true
            return
        }
        hasUnseen = newest > seen
    }

    /// Called when the Activity tab is actually shown.
    ///
    /// The marker is set to the newest timestamp *this refresh knew about*, not to `now`:
    /// using the clock would silently mark as read anything written between the fetch and the
    /// tap, and phone clocks disagree with Postgres anyway.
    func markSeen() {
        guard let userId else { return }
        if let latest {
            UserDefaults.standard.set(latest.timeIntervalSince1970, forKey: seenKey(for: userId))
        }
        hasUnseen = false
    }

    /// Clears in-memory state on sign-out. The stored marker stays: it belongs to that
    /// account and should still be there if they sign back in.
    func reset() {
        userId = nil
        latest = nil
        hasUnseen = false
    }
}
