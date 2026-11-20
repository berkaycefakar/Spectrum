import SwiftUI

/// Everything needed to draw the "Sent to you" row: the shares plus what they point at.
struct SharesInbox {
    var shares: [Share] = []
    var tracks: [Int64: Track] = [:]
    var albums: [Int64: Album] = [:]
    var senders: [UUID: Profile] = [:]

    var isEmpty: Bool { shares.isEmpty }

    /// Loads the inbox and resolves its songs, albums and senders in parallel.
    static func load() async -> SharesInbox {
        let shares = (try? await SupabaseManager.shared.fetchInbox()) ?? []
        guard !shares.isEmpty else { return SharesInbox() }
        let songIds = shares.filter { $0.kind == .song }.compactMap(\.catalogId)
        let albumIds = shares.filter { $0.kind == .album }.compactMap(\.catalogId)
        async let tracks = songIds.isEmpty ? [:] : MusicService.shared.fetchTracks(ids: songIds)
        async let albums = albumIds.isEmpty ? [:] : MusicService.shared.fetchAlbums(ids: albumIds)
        async let senders = (try? SupabaseManager.shared.batchGetProfiles(ids: Array(Set(shares.map(\.senderId.uuidString))))) ?? []
        let (t, a, s) = await (tracks, albums, senders)
        return SharesInbox(shares: shares, tracks: t, albums: a,
                           senders: Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0) }))
    }
}

/// "Sent to you": what friends sent, side by side, newest first. An unseen one carries a
/// dot; opening it marks it seen.
struct SharesInboxSection: View {
    @Binding var inbox: SharesInbox
    let open: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Sent to you", bundle: appStringsBundle)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.4))
                let unseen = inbox.shares.filter { $0.seenAt == nil }.count
                if unseen > 0 {
                    Text("\(unseen)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.spectrumAccent)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(inbox.shares) { share in
                        if let route = route(for: share) {
                            card(share)
                                .onTapGesture {
                                    open(route)
                                    markSeen(share)
                                }
                                .accessibilityAddTraits(.isButton)
                                .moderationActions(
                                    contentType: .share,
                                    contentRef: share.id.uuidString,
                                    authorId: share.senderId,
                                    authorUsername: inbox.senders[share.senderId]?.username,
                                    reportedText: share.note,
                                    onBlocked: { remove(share) },
                                    onDelete: {
                                        remove(share)
                                        Task { try? await SupabaseManager.shared.deleteShare(id: share.id) }
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func route(for share: Share) -> AppRoute? {
        guard let id = share.catalogId else { return nil }
        switch share.kind {
        case .song: return inbox.tracks[id].map { .track($0) }
        case .album: return inbox.albums[id].map { .album($0) }
        }
    }

    private func card(_ share: Share) -> some View {
        let sender = inbox.senders[share.senderId]
        let name = sender?.username ?? String(localized: "Someone", bundle: appStringsBundle)
        let id = share.catalogId ?? 0
        let title = share.kind == .song ? inbox.tracks[id]?.title : inbox.albums[id]?.title
        let artist = share.kind == .song ? inbox.tracks[id]?.artist : inbox.albums[id]?.artist
        let art = share.kind == .song ? inbox.tracks[id]?.artworkUrl600 : inbox.albums[id]?.artworkUrl600

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProfileAvatar(url: sender?.avatarUrl, name: name, size: 24)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if share.seenAt == nil {
                    Circle().fill(Color.spectrumAccent).frame(width: 8, height: 8)
                        .accessibilityLabel(Text("New", bundle: appStringsBundle))
                }
                Text(share.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 10) {
                AsyncImage(url: art) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                    else { Color.white.opacity(0.08) }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            if let note = share.note, !note.isEmpty {
                Text(ProfanityFilter.masked(note))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .topLeading)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(.white.opacity(share.seenAt == nil ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private func markSeen(_ share: Share) {
        guard share.seenAt == nil, let i = inbox.shares.firstIndex(of: share) else { return }
        let s = inbox.shares[i]
        inbox.shares[i] = Share(id: s.id, senderId: s.senderId, recipientId: s.recipientId, kind: s.kind,
                                contentRef: s.contentRef, note: s.note, createdAt: s.createdAt, seenAt: Date())
        Task { await SupabaseManager.shared.markSharesSeen([s.id]) }
    }

    private func remove(_ share: Share) {
        inbox.shares.removeAll { $0.id == share.id }
    }
}
