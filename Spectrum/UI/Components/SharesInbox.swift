import SwiftUI

/// Everything needed to draw a "Sent to you" or "You sent" row: the shares plus what they
/// point at. `people` holds the other party: the sender for received, the recipient for sent.
struct SharesInbox {
    var shares: [Share] = []
    var tracks: [Int64: Track] = [:]
    var albums: [Int64: Album] = [:]
    var people: [UUID: Profile] = [:]
    var isSent = false

    var isEmpty: Bool { shares.isEmpty }

    func otherParty(of share: Share) -> UUID { isSent ? share.recipientId : share.senderId }

    /// Loads received (or sent) shares and resolves songs, albums and people in parallel.
    static func load(sent: Bool = false) async -> SharesInbox {
        let shares = (try? await (sent ? SupabaseManager.shared.fetchSent() : SupabaseManager.shared.fetchInbox())) ?? []
        guard !shares.isEmpty else { return SharesInbox(isSent: sent) }
        let songIds = shares.filter { $0.kind == .song }.compactMap(\.catalogId)
        let albumIds = shares.filter { $0.kind == .album }.compactMap(\.catalogId)
        async let tracks = songIds.isEmpty ? [:] : MusicService.shared.fetchTracks(ids: songIds)
        async let albums = albumIds.isEmpty ? [:] : MusicService.shared.fetchAlbums(ids: albumIds)
        let otherIds = Set(shares.map { sent ? $0.recipientId : $0.senderId }).map(\.uuidString)
        async let people = (try? SupabaseManager.shared.batchGetProfiles(ids: Array(otherIds))) ?? []
        let (t, a, p) = await (tracks, albums, people)
        return SharesInbox(shares: shares, tracks: t, albums: a,
                           people: Dictionary(uniqueKeysWithValues: p.map { ($0.id, $0) }), isSent: sent)
    }
}

/// Songs and albums friends sent you, and the ones you sent, on their own screen. Opened from
/// the paper plane on Home, like a message inbox; it used to be two cramped carousels on top
/// of Activity, where a long note was cut in half.
struct SharesInboxView: View {
    let open: (AppRoute) -> Void

    @State private var tab = 0
    @State private var received = SharesInbox()
    @State private var sent = SharesInbox(isSent: true)
    @State private var isLoading = true

    private var current: Binding<SharesInbox> { tab == 0 ? $received : $sent }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("", selection: $tab) {
                        Text("Received", bundle: appStringsBundle).tag(0)
                        Text("Sent", bundle: appStringsBundle).tag(1)
                    }
                    .pickerStyle(.segmented)

                    if isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if current.wrappedValue.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(current.wrappedValue.shares) { share in
                                ShareRow(inbox: current, share: share, open: open)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(Text("Shared with friends", bundle: appStringsBundle))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let r = SharesInbox.load()
            async let s = SharesInbox.load(sent: true)
            (received, sent) = await (r, s)
            isLoading = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "paperplane")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(tab == 0 ? "Nothing yet. When a friend sends you a song, it lands here."
                          : "Send a song from its page: Share → Send to a friend.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

/// The inbox as a pushed screen; a tapped row pushes the song or album on top of it.
struct SharesInboxRoute: View {
    @State private var target: AppRoute?

    var body: some View {
        SharesInboxView { target = $0 }
            .navigationDestination(item: $target) { AppRouteView(route: $0) }
    }
}

/// One share, full width: who, what, the note in full, and when.
private struct ShareRow: View {
    @Binding var inbox: SharesInbox
    let share: Share
    let open: (AppRoute) -> Void

    var body: some View {
        if let route = route {
            card
                .onTapGesture {
                    open(route)
                    if !inbox.isSent { markSeen() }
                }
                .accessibilityAddTraits(.isButton)
                .moderationActions(
                    contentType: .share,
                    contentRef: share.id.uuidString,
                    authorId: share.senderId,
                    authorUsername: inbox.people[share.senderId]?.username,
                    reportedText: share.note,
                    onBlocked: { remove() },
                    onDelete: {
                        remove()
                        Task { try? await SupabaseManager.shared.deleteShare(id: share.id) }
                    }
                )
        }
    }

    private var route: AppRoute? {
        guard let id = share.catalogId else { return nil }
        switch share.kind {
        case .song: return inbox.tracks[id].map { .track($0) }
        case .album: return inbox.albums[id].map { .album($0) }
        }
    }

    private var card: some View {
        let person = inbox.people[inbox.otherParty(of: share)]
        let name = person?.username ?? String(localized: "Someone", bundle: appStringsBundle)
        let id = share.catalogId ?? 0
        let title = share.kind == .song ? inbox.tracks[id]?.title : inbox.albums[id]?.title
        let artist = share.kind == .song ? inbox.tracks[id]?.artist : inbox.albums[id]?.artist
        let art = share.kind == .song ? inbox.tracks[id]?.artworkUrl600 : inbox.albums[id]?.artworkUrl600
        let unseen = !inbox.isSent && share.seenAt == nil

        return HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: art) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                else { Color.white.opacity(0.08) }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ProfileAvatar(url: person?.avatarUrl, name: name, size: 20)
                    Text(inbox.isSent ? String(localized: "To \(name)", bundle: appStringsBundle) : name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if inbox.isSent, share.seenAt != nil {
                        Text("Seen", bundle: appStringsBundle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    if unseen {
                        Circle().fill(Color.spectrumAccent).frame(width: 8, height: 8)
                            .accessibilityLabel(Text("New", bundle: appStringsBundle))
                    }
                    Text(share.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text(title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                if let note = share.note, !note.isEmpty {
                    Text(ProfanityFilter.masked(note))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(unseen ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private func markSeen() {
        guard share.seenAt == nil, let i = inbox.shares.firstIndex(of: share) else { return }
        let s = inbox.shares[i]
        inbox.shares[i] = Share(id: s.id, senderId: s.senderId, recipientId: s.recipientId, kind: s.kind,
                                contentRef: s.contentRef, note: s.note, createdAt: s.createdAt, seenAt: Date())
        Task { await SupabaseManager.shared.markSharesSeen([s.id]) }
    }

    private func remove() {
        inbox.shares.removeAll { $0.id == share.id }
    }
}
