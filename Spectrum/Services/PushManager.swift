import UIKit
import UserNotifications
import Supabase

/// Push notifications: asks once, registers with APNs and stores this device's token in
/// `device_tokens` so the backend can reach the signed-in user.
@MainActor
final class PushManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushManager()

    /// Asks for permission the first time (later calls just re-register, which is how iOS
    /// hands back a token that may have changed).
    func registerIfSignedIn() async {
        if DemoMode.isOn { return }
        guard (try? await SupabaseManager.shared.getCurrentUser()) != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func didRegister(token data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Task { await SupabaseManager.shared.saveDeviceToken(token) }
    }

    /// Show banners while the app is open too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugLog("APNs registration failed: \(error)")
    }
}
