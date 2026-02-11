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
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)
            
            // After successful sign in, get the user
            if let user = try await SupabaseManager.shared.getCurrentUser() {
                self.currentUser = user
                await loadProfile()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseManager.shared.signUp(email: email, password: password, username: username)
            
            // After successful sign up, get the user
            if let user = try await SupabaseManager.shared.getCurrentUser() {
                self.currentUser = user
                await loadProfile()
            }
            
            isLoading = false
        } catch {
            isLoading = false
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
            self.currentUser = nil
            self.currentProfile = nil
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
        
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
