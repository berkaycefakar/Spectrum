import SwiftUI
import Supabase

/// Lightweight settings sheet: account info, MusicKit status, app version, and log out.
struct SettingsView: View {
    @Binding var isPresented: Bool
    let onLogout: () -> Void

    @State private var email: String?
    @State private var showLogoutAlert = false

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
                }

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

                Spacer()
            }
        }
        .task {
            email = try? await SupabaseManager.shared.getCurrentUser()?.email
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
}
