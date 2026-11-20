import SwiftUI

/// "Send to a friend": pick one or more mutual follows, add a line, send.
///
/// Deliberately not a chat. A share is a record and a note; the friend sees it under
/// Activity › Sent to you. Only people you follow and who follow you back are listed, which is
/// also what the server enforces.
struct SendToFriendView: View {
    let kind: Share.Kind
    let contentRef: String
    let title: String
    let subtitle: String
    let artworkURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Profile] = []
    @State private var selected: Set<UUID> = []
    @State private var note = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sent = false
    @FocusState private var noteFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if friends.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(friends) { friend in friendCell(friend) }
                        }
                        .padding(20)
                    }
                    composer
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
        .sensoryFeedback(.success, trigger: sent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AsyncImage(url: artworkURL) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                else { Color.white.opacity(0.1) }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Send to a friend", bundle: appStringsBundle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(title) · \(subtitle)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.3))
            Text("No one to send to yet", bundle: appStringsBundle)
                .font(.headline)
                .foregroundStyle(.white)
            Text("You can send music to people you follow who follow you back.", bundle: appStringsBundle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func friendCell(_ friend: Profile) -> some View {
        let isOn = selected.contains(friend.id)
        let name = friend.username ?? String(localized: "User", bundle: appStringsBundle)
        return Button {
            if isOn { selected.remove(friend.id) } else { selected.insert(friend.id) }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(url: friend.avatarUrl, name: name, size: 60)
                        .overlay(Circle().stroke(isOn ? Color.spectrumAccent : .clear, lineWidth: 3))
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.black, Color.spectrumAccent)
                    }
                }
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(isOn ? 1 : 0.75))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#FF6B6B"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                TextField(String(localized: "Add a note (optional)", bundle: appStringsBundle), text: $note, axis: .vertical)
                    .focused($noteFocused)
                    .lineLimit(1...3)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .onChange(of: note) { _, new in
                        if new.count > SupabaseManager.shareNoteMaxLength {
                            note = String(new.prefix(SupabaseManager.shareNoteMaxLength))
                        }
                        errorMessage = nil
                    }
                Button { Task { await send() } } label: {
                    Group {
                        if isSending { ProgressView().tint(.black) }
                        else { Text(sendTitle).font(.subheadline.weight(.bold)) }
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(selected.isEmpty ? Color.white.opacity(0.3) : Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty || isSending)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black)
    }

    private var sendTitle: String {
        selected.count > 1
            ? String(localized: "Send to \(selected.count)", bundle: appStringsBundle)
            : String(localized: "Send", bundle: appStringsBundle)
    }

    private func load() async {
        friends = (try? await SupabaseManager.shared.mutualFriends()) ?? []
        isLoading = false
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            try await SupabaseManager.shared.sendShare(kind: kind, contentRef: contentRef, note: note, to: Array(selected))
            sent = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A user's photo in a circle, or their initial when they have none.
struct ProfileAvatar: View {
    let url: String?
    let name: String
    var size: CGFloat = 32

    var body: some View {
        let initial = Circle()
            .fill(.white.opacity(0.12))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
        Group {
            if let url = url.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { initial }
                }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
