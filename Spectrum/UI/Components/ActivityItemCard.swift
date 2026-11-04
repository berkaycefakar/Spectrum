import SwiftUI

struct ActivityItemCard: View {
    let activity: ActivityItem

    // Artwork fetched from iTunes based on targetId
    @State private var artworkUrl: URL?
    @State private var targetTitle: String?

    var body: some View {
        Group {
            // Value-based so the Activity tab can pop back to its root when re-tapped. Rows
            // with an unusable target id stay unpushable rather than opening a dead end.
            if let route = activityRoute {
                NavigationLink(value: route) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent
            }
        }
        .task {
            await loadTargetInfo()
        }
    }

    private var activityRoute: AppRoute? {
        switch activity.type {
        case .trackReview:
            guard let targetId = activity.targetId, let trackId = Int64(targetId) else { return nil }
            return .activityTrack(trackId)
        case .albumReview:
            guard let targetId = activity.targetId, let collectionId = Int64(targetId) else { return nil }
            return .activityAlbum(collectionId)
        case .newFollower:
            return .user(activity.actorId)
        }
    }

    // MARK: - Navigation Destination
    @ViewBuilder
    private var activityDestination: some View {
        switch activity.type {
        case .trackReview:
            if let targetId = activity.targetId, let trackId = Int64(targetId) {
                ActivityTrackDestination(trackId: trackId)
            } else {
                emptyDestination
            }
        case .albumReview:
            if let targetId = activity.targetId, let collectionId = Int64(targetId) {
                ActivityAlbumDestination(collectionId: collectionId)
            } else {
                emptyDestination
            }
        case .newFollower:
            UserProfileView(userId: activity.actorId)
        }
    }

    private var emptyDestination: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Content unavailable")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Card Content
    @ViewBuilder
    private var cardContent: some View {
        if activity.type == .newFollower {
            followerRow
        } else {
            logCard
        }
    }

    private var vibe: Color { Color(hex: activity.vibeColor ?? "#FF2D55") }

    /// A log, tinted with the vibe its author picked.
    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                avatar(size: 28)
                (
                    Text(activity.actorUsername ?? String(localized: "Someone", bundle: appStringsBundle)).fontWeight(.semibold).foregroundColor(.white)
                    + Text(" \(actionPhrase)").foregroundColor(.white.opacity(0.6))
                )
                .font(.subheadline)
                .lineLimit(1)
                Spacer(minLength: 4)
                Text(activity.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 14) {
                artworkThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleParts.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let artist = titleParts.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        if let hex = activity.vibeColor {
                            Text(VibePalette.label(for: hex))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(vibe.opacity(0.22), in: Capsule())
                                .overlay(Capsule().stroke(vibe, lineWidth: 1))
                        }
                        if let rating = activity.rating {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#FFCC00"))
                                Text(String(format: "%.1f", Double(rating) / 2.0))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            if let text = activity.reviewText, !text.isEmpty {
                Text("\u{201C}\(ProfanityFilter.masked(text))\u{201D}")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [vibe.opacity(0.24), .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.75, y: 0.9)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
    }

    /// "Title - Artist" from the catalog lookup, split back into its two lines.
    private var titleParts: (title: String, artist: String?) {
        if let full = targetTitle, let range = full.range(of: " - ") {
            return (String(full[..<range.lowerBound]), String(full[range.upperBound...]))
        }
        return (targetTitle ?? activity.targetName ?? "", nil)
    }

    private var followerRow: some View {
        HStack(spacing: 12) {
            avatar(size: 40)
            (
                Text(activity.actorUsername ?? String(localized: "Someone", bundle: appStringsBundle)).fontWeight(.semibold).foregroundColor(.white)
                + Text(" \(actionPhrase)").foregroundColor(.white.opacity(0.6))
                + Text(" · \(activity.createdAt.timeAgoDisplay())").foregroundColor(.white.opacity(0.4))
            )
            .font(.subheadline)
            .lineLimit(2)
            Spacer(minLength: 4)
            FollowBackButton(userId: activity.actorId)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func avatar(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: "#3A2A4A"))
            if let urlString = activity.actorAvatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        userInitial
                    }
                }
            } else {
                userInitial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .font(.system(size: size * 0.42, weight: .bold))
    }

    /// Verb-only phrase; the username is rendered separately in bold.
    private var actionPhrase: String {
        switch activity.type {
        case .trackReview: return String(localized: "logged a track", bundle: appStringsBundle)
        case .albumReview: return String(localized: "reviewed an album", bundle: appStringsBundle)
        case .newFollower: return String(localized: "started following you", bundle: appStringsBundle)
        }
    }

    // MARK: - Artwork Thumbnail
    @ViewBuilder
    private var artworkThumbnail: some View {
        switch activity.type {
        case .trackReview, .albumReview:
            // Show actual track/album artwork
            ZStack {
                if let url = artworkUrl {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            artworkPlaceholder
                        }
                    }
                } else {
                    artworkPlaceholder
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14))

        case .newFollower:
            // Show user avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.4), accentColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let urlString = activity.actorAvatarUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            userInitial
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    userInitial
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            accentColor.opacity(0.15)
            Image(systemName: activity.type == .albumReview ? "opticaldisc" : "music.note")
                .font(.system(size: 18))
                .foregroundStyle(accentColor.opacity(0.6))
        }
    }

    private var userInitial: some View {
        Text(String((activity.actorUsername ?? "U").prefix(1)).uppercased())
            .foregroundStyle(.white)
    }

    // MARK: - Data Loading
    private func loadTargetInfo() async {
        guard let targetId = activity.targetId else { return }

        switch activity.type {
        case .trackReview:
            if let id = Int64(targetId),
               let track = try? await MusicService.shared.fetchTrack(id: id) {
                await MainActor.run {
                    self.artworkUrl = track.artworkUrl600
                    self.targetTitle = "\(track.title) - \(track.artist)"
                }
            }
        case .albumReview:
            if let id = Int64(targetId),
               let album = try? await MusicService.shared.fetchAlbum(collectionId: id) {
                await MainActor.run {
                    self.artworkUrl = album.artworkUrl600
                    self.targetTitle = "\(album.title) - \(album.artist)"
                }
            }
        case .newFollower:
            break
        }
    }

    // MARK: - Helpers
    private var accentColor: Color {
        switch activity.type {
        case .trackReview:
            return Color(hex: "#FF2D55")
        case .albumReview:
            return Color(hex: "#00FFFF")
        case .newFollower:
            return Color(hex: "#FF9500")
        }
    }

    private var primaryText: String {
        let username = activity.actorUsername ?? String(localized: "Someone", bundle: appStringsBundle)
        switch activity.type {
        case .trackReview:
            return String(localized: "\(username) logged a track", bundle: appStringsBundle)
        case .albumReview:
            return String(localized: "\(username) reviewed an album", bundle: appStringsBundle)
        case .newFollower:
            return String(localized: "\(username) started following you", bundle: appStringsBundle)
        }
    }
}

// MARK: - Follow Back

/// "Follow" / "Following" toggle on a new-follower row.
private struct FollowBackButton: View {
    let userId: UUID
    @State private var isFollowing: Bool?
    @State private var isBusy = false

    var body: some View {
        Button {
            guard let current = isFollowing, !isBusy else { return }
            isBusy = true
            isFollowing = !current
            Task {
                do {
                    if current {
                        try await SupabaseManager.shared.unfollowUser(userId: userId)
                    } else {
                        try await SupabaseManager.shared.followUser(userId: userId)
                    }
                } catch {
                    await MainActor.run { isFollowing = current }
                }
                await MainActor.run { isBusy = false }
            }
        } label: {
            let following = isFollowing ?? false
            Text(following ? "Following" : "Follow")
                .font(.caption.weight(.bold))
                .foregroundStyle(following ? .white : .black)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(following ? AnyShapeStyle(.clear) : AnyShapeStyle(.white), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(following ? 0.25 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(isFollowing == nil ? 0 : 1)
        .task {
            isFollowing = (try? await SupabaseManager.shared.isFollowing(userId: userId)) ?? false
        }
    }
}

// MARK: - Activity Track Destination

struct ActivityTrackDestination: View {
    let trackId: Int64
    @State private var track: Track?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let track {
                TrackDetailView(track: track)
            } else if failed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Could not load track")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            do {
                let fetched = try await MusicService.shared.fetchTrack(id: trackId)
                await MainActor.run {
                    self.track = fetched
                    self.failed = fetched == nil
                }
            } catch {
                await MainActor.run { self.failed = true }
            }
        }
    }
}

// MARK: - Activity Album Destination

struct ActivityAlbumDestination: View {
    let collectionId: Int64
    @State private var album: Album?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let album {
                AlbumDetailView(album: album)
            } else if failed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Could not load album")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            do {
                let fetched = try await MusicService.shared.fetchAlbum(collectionId: collectionId)
                await MainActor.run {
                    self.album = fetched
                    self.failed = fetched == nil
                }
            } catch {
                await MainActor.run { self.failed = true }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            ActivityItemCard(
                activity: ActivityItem(
                    id: UUID(),
                    type: .trackReview,
                    actorId: UUID(),
                    actorUsername: "berkay",
                    actorAvatarUrl: nil,
                    targetId: "1488408568",
                    targetName: "Blinding Lights",
                    rating: 9,
                    vibeColor: "#FF2D55",
                    reviewText: "Incredible production and energy.",
                    createdAt: Date().addingTimeInterval(-3600)
                )
            )
            ActivityItemCard(
                activity: ActivityItem(
                    id: UUID(),
                    type: .newFollower,
                    actorId: UUID(),
                    actorUsername: "johndoe",
                    actorAvatarUrl: nil,
                    targetId: nil,
                    targetName: nil,
                    rating: nil,
                    vibeColor: nil,
                    reviewText: nil,
                    createdAt: Date().addingTimeInterval(-7200)
                )
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
