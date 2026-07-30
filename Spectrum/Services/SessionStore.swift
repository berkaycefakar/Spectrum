import Foundation
import Supabase
import SwiftUI
import Combine

/// App-wide authentication state manager
/// Provides reactive auth state via @Published properties
@MainActor
class SessionStore: ObservableObject {
    static let shared = SessionStore()
    
    // MARK: - Published State
    @Published var currentUser: User?
    @Published var currentProfile: Profile?
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    /// True from the moment a password-recovery link is opened until a new password is saved
    /// (or the user backs out).
    @Published var isPasswordRecovery: Bool = false
    
    /// Returns true if user is authenticated
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    private init() {
        Task { await startAuthStateListener() }
    }
    
    /// Listens to Supabase auth changes so we auto-update after email confirmation / login.
    private func startAuthStateListener() async {
        for await (event, session) in SupabaseManager.shared.client.auth.authStateChanges {
            // Second signal for password recovery. The SDK only emits this from the
            // implicit-flow handler, so `AuthDeepLink` covers the PKCE case from the URL.
            if event == .passwordRecovery {
                if let session { self.currentUser = session.user }
                self.isPasswordRecovery = true
                self.isLoading = false
                continue
            }

            // Whoever is signed in now, the previous account's blocked-user list must not
            // survive into their session: it silently filters the feed, and the Settings
            // screen would disagree with what the feed shows.
            if event == .signedIn || event == .signedOut {
                await SupabaseManager.shared.invalidateBlockedCache()
            }

            guard [.initialSession, .signedIn, .tokenRefreshed].contains(event) else {
                if event == .signedOut {
                    self.currentUser = nil
                    self.currentProfile = nil
                }
                continue
            }
            if let session = session {
                self.currentUser = session.user
                await loadProfile()
            } else {
                self.currentUser = nil
                self.currentProfile = nil
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Session Check
    
    /// Check for existing session on app launch
    func checkSession() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let user = try await SupabaseManager.shared.getCurrentUser() {
                self.currentUser = user
                // Also load the profile
                await loadProfile()
            } else {
                self.currentUser = nil
                self.currentProfile = nil
            }
        } catch {
            print("Session check error: \(error)")
            self.currentUser = nil
            self.currentProfile = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In
    
    /// - Important: this must NOT set `isLoading`.
    ///
    /// `ContentView` renders `SplashView` whenever `isLoading` is true, so flipping it here
    /// tore `AuthView` off the screen the instant the user tapped Log In. The error was then
    /// assigned to a view that no longer existed, and when the request finished SwiftUI built
    /// a *fresh* `AuthView` with an empty `errorMessage` — which is why a wrong password
    /// looked like nothing happening at all. `isLoading` means "restoring the session at
    /// launch"; an in-flight form submission is the form's own local state.
    func signIn(email: String, password: String) async throws {
        errorMessage = nil

        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)

            // After successful sign in, get the user
            if let user = try await SupabaseManager.shared.getCurrentUser() {
                self.currentUser = user
                // Covers accounts created while email confirmation was on, whose profile row
                // could not be written at sign-up time.
                _ = try? await SupabaseManager.shared.ensureProfile(
                    userId: user.id,
                    preferredUsername: user.email
                )
                await loadProfile()
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Social sign-in

    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        errorMessage = nil
        do {
            try await SupabaseManager.shared.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName)
            await refreshAfterExternalSignIn()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signInWithGoogle() async throws {
        errorMessage = nil
        do {
            try await SupabaseManager.shared.signInWithGoogle()
            await refreshAfterExternalSignIn()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func refreshAfterExternalSignIn() async {
        if let user = try? await SupabaseManager.shared.getCurrentUser() {
            self.currentUser = user
            await loadProfile()
        }
    }

    // MARK: - Password reset

    func sendPasswordReset(email: String) async throws {
        try await SupabaseManager.shared.sendPasswordReset(email: email)
    }

    /// Called when a `type=recovery` callback arrives, so the UI can put the "choose a new
    /// password" screen in front of everything else.
    func beginPasswordRecovery() {
        isPasswordRecovery = true
    }

    func endPasswordRecovery() {
        isPasswordRecovery = false
    }

    /// Sets a new password for the signed-in account.
    ///
    /// The recovery link signs the user in first, which is what makes this authorised — it is
    /// also why the recovery screen must be shown: without it the link would log someone in
    /// and leave the password they'd forgotten still in place.
    func updatePassword(_ newPassword: String) async throws {
        try await SupabaseManager.shared.updatePassword(newPassword)
        isPasswordRecovery = false
    }
    
    // MARK: - Sign Up
    
    /// Same `isLoading` rule as `signIn` — see the note there.
    @discardableResult
    func signUp(email: String, password: String, username: String) async throws -> SupabaseManager.SignUpOutcome {
        errorMessage = nil

        do {
            let outcome = try await SupabaseManager.shared.signUp(
                email: email,
                password: password,
                username: username
            )

            // Straight into the app — no "now go and log in with the details you just typed".
            if outcome == .signedIn, let user = try await SupabaseManager.shared.getCurrentUser() {
                self.currentUser = user
                await loadProfile()
            }

            return outcome
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseManager.shared.signOut()
        } catch {
            // Logged, not surfaced. The local state is cleared either way below: a failed
            // network round-trip used to leave `currentUser` set, so the app kept showing the
            // signed-in tabs after the user asked to leave — and after deleting their
            // account, where the second sign-out call naturally fails because the session is
            // already gone.
            print("Sign out request failed (clearing local session anyway):", error)
        }

        self.currentUser = nil
        self.currentProfile = nil
        isLoading = false
    }
    
    // MARK: - Profile Loading
    
    func loadProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile = try await SupabaseManager.shared.getProfile(userId: userId)
            self.currentProfile = profile
        } catch {
            print("Failed to load profile: \(error)")
            // Don't set error message - profile might not exist yet
        }
    }
    
    /// Refresh profile after updates
    func refreshProfile() async {
        await loadProfile()
    }
}
