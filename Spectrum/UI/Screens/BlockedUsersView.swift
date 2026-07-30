import SwiftUI

/// Manage the block list. Apple expects blocking to be reversible from inside the app, so this
/// screen is part of the Guideline 1.2 requirement, not a nice-to-have.
struct BlockedUsersView: View {
    @State private var blocked: [BlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unblocking: Set<UUID> = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if blocked.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No blocked users")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("People you block stop appearing in your feed, search and activity.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(blocked) { entry in
                            row(for: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(for entry: BlockedUser) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String((entry.profile.username ?? "U").prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            Text(entry.profile.username ?? "Unknown")
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                Task { await unblock(entry) }
            } label: {
                // Padding inside the label so the whole pill is the tap target.
                Group {
                    if unblocking.contains(entry.id) {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unblock").fontWeight(.semibold)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .disabled(unblocking.contains(entry.id))
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        do {
            let list = try await SupabaseManager.shared.fetchBlockedUsers()
            blocked = list
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func unblock(_ entry: BlockedUser) async {
        unblocking.insert(entry.id)
        do {
            try await SupabaseManager.shared.unblockUser(entry.profile.id)
            blocked.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        unblocking.remove(entry.id)
    }
}
