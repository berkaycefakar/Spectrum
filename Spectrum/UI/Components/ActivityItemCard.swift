import SwiftUI

struct ActivityItemCard: View {
    let activity: ActivityItem

    // Artwork fetched from iTunes based on targetId
    @State private var artworkUrl: URL?
    @State private var targetTitle: String?

    var body: some View {
        NavigationLink(destination: activityDestination) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadTargetInfo()
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
    private var cardContent: some View {
        HStack(spacing: 14) {
            // Artwork / avatar with a small action-type badge in the corner.
            artworkThumbnail
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(accentColor)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.black.opacity(0.85), lineWidth: 2))
                        .offset(x: 5, y: 5)
                }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Username (bold) + action (muted), on one flowing line.
                (
                    Text(activity.actorUsername ?? "Someone").fontWeight(.semibold).foregroundColor(.white)
                    + Text(" \(actionPhrase)").foregroundColor(.white.opacity(0.55))
                )
                .font(.subheadline)
                .lineLimit(1)

                // Target name (track/album title)
                if let title = targetTitle ?? activity.targetName {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                // Review text snippet
                if let text = activity.reviewText, !text.isEmpty {
                    Text("\u{201C}\(text)\u{201D}")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .italic()
                }

                // Rating + time
                HStack(spacing: 10) {
                    if let rating = activity.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "#FFCC00"))
                            Text(String(format: "%.1f", Double(rating) / 2.0))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        if let vibe = activity.vibeColor {
                            Circle()
                                .fill(Color(hex: vibe))
                                .frame(width: 8, height: 8)
                                .shadow(color: Color(hex: vibe).opacity(0.6), radius: 3)
                        }
                    }

                    Text(activity.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.top, 1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.35), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accentColor.opacity(0.12), radius: 10, y: 4)
    }

    private var badgeIcon: String {
        switch activity.type {
        case .trackReview: return "star.fill"
        case .albumReview: return "opticaldisc.fill"
        case .newFollower: return "person.fill.badge.plus"
        }
    }

    /// Verb-only phrase; the username is rendered separately in bold.
    private var actionPhrase: String {
        switch activity.type {
        case .trackReview: return "logged a track"
        case .albumReview: return "reviewed an album"
        case .newFollower: return "started following you"
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
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(0.2), radius: 6)

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
            .font(.headline)
            .fontWeight(.bold)
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
        let username = activity.actorUsername ?? "Someone"
        switch activity.type {
        case .trackReview:
            return "\(username) logged a track"
        case .albumReview:
            return "\(username) reviewed an album"
        case .newFollower:
            return "\(username) started following you"
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
