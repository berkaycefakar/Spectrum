import SwiftUI
import Supabase

/// Settings sheet: who is signed in, language, account safety, legal links, log out and delete.
struct SettingsView: View {
    @StateObject private var language = LanguagePreference.shared
    @ObservedObject private var session = SessionStore.shared
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

            Circle()
                .fill(Color(hex: "#5856D6").opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: 140, y: -300)
                .allowsHitTesting(false)

            // Scrolls: the old fixed stack ran past the bottom of smaller phones, which put
            // Delete Account — the one row Apple insists be easy to find — off screen.
            ScrollView {
                VStack(spacing: 26) {
                    header
                    accountCard

                    section(String(localized: "Preferences", bundle: appStringsBundle)) {
                        languageRow
                    }

                    section(String(localized: "Account", bundle: appStringsBundle)) {
                        navRow(icon: "key.fill", tint: "#8E8E93",
                               title: String(localized: "Change Password", bundle: appStringsBundle)) {
                            showChangePassword = true
                        }
                        rowDivider
                        // Blocking has to be undoable from inside the app for Guideline 1.2,
                        // which means the list needs a home somewhere the user can find it.
                        navRow(icon: "hand.raised.fill", tint: "#FF9500",
                               title: String(localized: "Blocked Users", bundle: appStringsBundle)) {
                            showBlockedUsers = true
                        }
                    }

                    section(String(localized: "About", bundle: appStringsBundle)) {
                        // Reachable after sign-up too, not only on the landing screen: a user
                        // who wants to re-read what they agreed to shouldn't have to log out.
                        linkRow(icon: "doc.text.fill", tint: "#007AFF",
                                label: String(localized: "Terms of Service", bundle: appStringsBundle), url: LegalLinks.terms)
                        rowDivider
                        linkRow(icon: "lock.fill", tint: "#4CD964",
                                label: String(localized: "Privacy Policy", bundle: appStringsBundle), url: LegalLinks.privacy)
                        rowDivider
                        linkRow(icon: "questionmark.bubble.fill", tint: "#FF2D55",
                                label: String(localized: "Contact Support", bundle: appStringsBundle), url: LegalLinks.support)
                    }

                    VStack(spacing: 12) {
                        Button {
                            showLogoutAlert = true
                        } label: {
                            Text("Log Out")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(hex: "#FF453A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
                        }
                        .disabled(isDeleting)

                        deleteAccountSection
                    }
                    .padding(.horizontal)

                    footer
                }
                .padding(.bottom, 40)
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
                    deleteError = String(localized: "Couldn't delete your account: \(error.localizedDescription)", bundle: appStringsBundle)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: "#FF4DFF"))
            }
        }
        .padding(.horizontal)
        .padding(.top, 18)
    }

    /// Who is signed in — the first thing someone opening Settings wants confirmed.
    private var accountCard: some View {
        let profile = session.currentProfile
        let name = profile?.username ?? String(localized: "Anonymous", bundle: appStringsBundle)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: "#3A2A4A"))
                if let avatar = profile?.avatarUrl, let url = URL(string: avatar) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            initial(name)
                        }
                    }
                } else {
                    initial(name)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(email ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }

    private func initial(_ name: String) -> some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            SpectrumMark(size: 30)
                .opacity(0.7)
            Text("Spectrum \(appVersion)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            Text("Music data from Apple Music")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Language

    /// One row with the current choice; the three options live in a menu rather than taking
    /// three rows of the screen for a setting most people touch once.
    private var languageRow: some View {
        Menu {
            Picker(selection: Binding(get: { language.choice }, set: { language.select($0) })) {
                ForEach(LanguagePreference.Choice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 12) {
                iconTile("globe", tint: "#5AC8FA")
                Text("Language")
                    .font(.body)
                    .foregroundStyle(.white)
                Spacer()
                Text(language.choice.label)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    private var rowDivider: some View {
        // Inset past the icon tile, the way grouped lists draw it.
        Divider()
            .overlay(.white.opacity(0.08))
            .padding(.leading, 58)
    }

    private func iconTile(_ systemName: String, tint: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color(hex: tint), in: RoundedRectangle(cornerRadius: 8))
    }

    private func navRow(icon: String, tint: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconTile(icon, tint: tint)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
    }

    private func linkRow(icon: String, tint: String, label: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                iconTile(icon, tint: tint)
                Text(label)
                    .font(.body)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            // Inside the label so the whole row is the tap target, not just the text.
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
    }
}
