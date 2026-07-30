import SwiftUI
import Supabase

/// Lightweight settings sheet: account info, MusicKit status, app version, and log out.
struct SettingsView: View {
    @Binding var isPresented: Bool
    let onLogout: () -> Void

    @State private var email: String?
    @State private var showLogoutAlert = false
    @State private var showChangePassword = false
    @State private var showBlockedUsers = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                ZStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    HStack {
                        Spacer()
                        Button("Done") { isPresented = false }
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Account section
                settingsCard(title: "Account") {
                    infoRow(label: "Email", value: email ?? "—")
                }

                // About section
                settingsCard(title: "About") {
                    infoRow(label: "Version", value: appVersion)
                    Divider().background(.white.opacity(0.08))
                    infoRow(label: "Music data", value: "Apple Music (MusicKit)")
                    Divider().background(.white.opacity(0.08))
                    // Reachable after sign-up too, not only on the landing screen: a user who
                    // wants to re-read what they agreed to shouldn't have to log out.
                    linkRow(label: "Terms of Service", url: LegalLinks.terms)
                    Divider().background(.white.opacity(0.08))
                    linkRow(label: "Privacy Policy", url: LegalLinks.privacy)
                    Divider().background(.white.opacity(0.08))
                    linkRow(label: "Contact Support", url: LegalLinks.support)
                }

                // Safety. Blocking has to be undoable from inside the app for Guideline 1.2,
                // which means the list needs a home somewhere the user can find it.
                Button {
                    showBlockedUsers = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                        Text("Blocked Users").fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(isDeleting)

                // Change password. Also the dependable way in if a future Supabase flow
                // change stops the recovery link from being recognised.
                Button {
                    showChangePassword = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                        Text("Change Password").fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(isDeleting)

                // Log out
                Button {
                    showLogoutAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out").fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .disabled(isDeleting)

                deleteAccountSection

                Spacer()
            }
        }
        .task {
            email = try? await SupabaseManager.shared.getCurrentUser()?.email
        }
        .sheet(isPresented: $showBlockedUsers) {
            NavigationStack {
                BlockedUsersView()
            }
            .preferredColorScheme(.dark)
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                isPresented = false
                onLogout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .sheet(isPresented: $showChangePassword) {
            NewPasswordView(mode: .change) {
                showChangePassword = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) { deleteAccount() }
        } message: {
            Text("This permanently deletes your profile, every song, album and artist you've logged, and everyone you follow. This can't be undone.")
        }
    }

    // MARK: - Delete account

    /// Required by App Store Review Guideline 5.1.1(v): an app that lets people create an
    /// account has to let them delete it from inside the app. Kept visually quiet and placed
    /// last so it can't be mistaken for "Log Out", but not hidden behind anything either —
    /// Apple expects it to be easy to find.
    private var deleteAccountSection: some View {
        VStack(spacing: 10) {
            Button {
                deleteError = nil
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView().tint(Color(hex: "#FF3B30"))
                        Text("Deleting...")
                    } else {
                        Image(systemName: "trash")
                        Text("Delete Account")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#FF3B30").opacity(isDeleting ? 0.6 : 1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#FF3B30").opacity(0.35), lineWidth: 1)
                )
            }
            .disabled(isDeleting)

            if let deleteError {
                Text(deleteError)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .multilineTextAlignment(.center)
            } else {
                Text("Permanently removes your account and all your logs.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil

        Task {
            do {
                try await SupabaseManager.shared.deleteAccount()
                await MainActor.run {
                    isDeleting = false
                    isPresented = false
                    // `deleteAccount` already ended the Supabase session; this drives the UI
                    // back to the landing screen.
                    onLogout()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = "Couldn't delete your account: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Building blocks

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func linkRow(label: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            // Inside the label so the whole row is the tap target, not just the text.
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}
