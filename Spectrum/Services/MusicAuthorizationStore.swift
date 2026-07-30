import Combine
import Foundation
import MusicKit
import SwiftUI

/// Tracks whether the user has granted Apple Music access, so the UI can say something useful
/// when they haven't.
///
/// Every catalog request — search, artwork, previews, the whole feed — needs `.authorized`.
/// Without this the app just rendered empty lists forever and looked broken, with no hint that
/// a permission was the cause or that it's fixable in Settings.
@MainActor
final class MusicAuthorizationStore: ObservableObject {
    static let shared = MusicAuthorizationStore()

    @Published private(set) var status: MusicAuthorization.Status = MusicAuthorization.currentStatus
    /// Set when the user chooses to look around anyway, so the explainer doesn't keep
    /// reappearing on every foreground.
    @Published var hasDismissedExplainer = false

    private init() {}

    /// True when catalog features cannot work and the user has to change something.
    var isBlocked: Bool {
        status == .denied || status == .restricted
    }

    var shouldShowExplainer: Bool {
        isBlocked && !hasDismissedExplainer
    }

    /// Prompts on first launch; afterwards just re-reads the system's answer.
    func requestIfNeeded() async {
        if MusicAuthorization.currentStatus == .notDetermined {
            status = await MusicAuthorization.request()
            debugLog("MusicKit: authorization status = \(status)")
        } else {
            refresh()
        }

        if isBlocked {
            debugLog("MusicKit: NOT authorized (\(status)) — catalog search and lookups will fail until the user grants access in Settings.")
        }
    }

    /// Re-reads the status. Call when returning from the background: the user may have just
    /// flipped the switch in Settings, and iOS gives no callback for that.
    func refresh() {
        let current = MusicAuthorization.currentStatus
        guard current != status else { return }
        status = current
        if current == .authorized {
            hasDismissedExplainer = false
        }
    }
}
