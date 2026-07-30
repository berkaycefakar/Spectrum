import SwiftUI

struct TrackDetailView: View {
    let track: Track

    @ObservedObject private var audioManager = AudioManager.shared
    @State private var showAddLog = false
    @State private var artworkColor: ArtworkColor = .placeholder

    private var dominantColor: Color { artworkColor.accent }

    /// The Log button is filled with the artwork accent, which can be anything from a dark
    /// navy to a pale cream — so its label has to follow the fill, not a fixed white.
    private var logTextColor: Color { dominantColor.contrastingForeground }

    private var isPlaying: Bool {
        audioManager.isTrackPlaying(track.id)
    }
    
    @State private var trackReviews: [Review] = []
    @State private var reviewProfiles: [UUID: Profile] = [:]
    @State private var isLoadingReviews = true
    @State private var album: Album?
    
    /// Average score, how many people logged it, and which vibe they picked most.
    private var communityStats: CommunityStats {
        CommunityStats(
            ratings: trackReviews.map(\.rating),
            vibeHexes: trackReviews.map(\.vibeColor)
        )
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    
                    VStack(spacing: 24) {
                        actionBar

                        if let album = album {
                            albumLink(album: album)
                        }

                        CommunityStatsCard(
                            stats: communityStats,
                            countLabel: "logs",
                            emptyMessage: "No logs yet — be the first!"
                        )

                        reviewsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    // A `Spacer(minLength:)` here made this whole column flexible, which is
                    // what let it squeeze the hero. Padding takes the space without stretching.
                    .padding(.bottom, 100)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddLog) {
            AddLogView(track: track, isPresented: $showAddLog)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            // Independent: the artwork colour is computed locally, the reviews come from
            // Supabase and the album from MusicKit. Chaining them made the page's perceived
            // load time the sum of all three.
            async let colorLoad: Void = loadArtworkColor()
            async let reviewsLoad: Void = loadTrackReviews()
            async let albumLoad: Void = loadAlbum()
            _ = await (colorLoad, reviewsLoad, albumLoad)
        }
        .onDisappear {
            if audioManager.isTrackPlaying(track.id) {
                audioManager.stop()
            }
        }
    }
    
    // MARK: - Hero Section

    /// The hero is pinned to this height on purpose. It used to size itself from whatever the
    /// ScrollView had left over, and because the reviews list below it is also flexible, every
    /// extra log stole height from the hero — which, being bottom-aligned, slid the artwork
    /// upward as a song gained logs.
    private let heroHeight: CGFloat = 420

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Blurred background — Color.clear takes the hero's box, the image overflows it
            // and gets clipped.
            Color.clear
                .overlay {
                    AsyncImage(url: track.artworkUrl600) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                }
                .clipped()
                .blur(radius: 50)
                .overlay(Color.black.opacity(0.4))

            LinearGradient(
                colors: [.clear, .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 20) {
                AsyncImage(url: track.artworkUrl600) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: dominantColor.opacity(0.6), radius: 30)

                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 20)

                    // Each credited artist is independently tappable — collaborations link to
                    // every performer's page, not just the primary one.
                    artistLinks
                }
            }
            .padding(.bottom, 30)
            .padding(.top, 50)
        }
        .frame(height: heroHeight)
        .clipped()
    }
    
    // MARK: - Artist links (supports collaborations)
    private var artistLinks: some View {
        let artists = track.displayArtists
        return FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(artists.enumerated()), id: \.element.id) { index, ref in
                HStack(spacing: 4) {
                    NavigationLink(destination: ArtistDetailView(artistName: ref.name, artistId: ref.artistId)) {
                        Text(ref.name)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    // Separator between multiple artists; chevron after the last one.
                    if index < artists.count - 1 {
                        Text("·")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 10) {
            // Log — primary action, wider
            Button {
                showAddLog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(logTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [dominantColor, dominantColor.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: dominantColor.opacity(0.4), radius: 12, y: 4)
                .animation(.easeInOut(duration: 0.45), value: dominantColor)
            }

            // Preview — circle button
            Button {
                toggleAudio()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [dominantColor.opacity(0.7), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    // A spinner while the preview downloads. The icon used to flip to "pause"
                    // instantly and then play nothing for seconds, which read as a dead button.
                    if audioManager.isTrackBuffering(track.id) {
                        ProgressView()
                            .tint(dominantColor)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(dominantColor)
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: dominantColor.opacity(0.35), radius: 8)
                .animation(.easeInOut(duration: 0.45), value: dominantColor)
            }
            .accessibilityLabel(isPlaying ? "Pause preview" : "Play preview")

            // Share — circle button
            Button {
                shareTrack()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Share")
        }
    }

    // MARK: - Album Link
    private func albumLink(album: Album) -> some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: 14) {
                AsyncImage(url: album.artworkUrl600) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("FROM THE ALBUM")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)
                    Text(album.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Reviews Section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only carries the written reviews now — the numbers moved into CommunityStatsCard.
            if !trackReviews.isEmpty || isLoadingReviews {
                Text("Reviews")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if isLoadingReviews {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if trackReviews.isEmpty {
                EmptyView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(trackReviews) { review in
                        TrackReviewCard(
                            review: review,
                            profile: reviewProfiles[review.userId]
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Data
    private func loadArtworkColor() async {
        let color = await ArtworkColorLoader.shared.color(for: track.artworkUrl600)
        withAnimation(.easeInOut(duration: 0.45)) {
            artworkColor = color
        }
    }

    private func loadTrackReviews() async {
        do {
            let reviews = try await SupabaseManager.shared.getTrackReviews(trackId: Int64(track.id))
            
            // One query for every reviewer rather than one per reviewer — a popular song was
            // firing a request per log.
            let userIds = Set(reviews.map { $0.userId }).map(\.uuidString)
            let fetchedProfiles = (try? await SupabaseManager.shared.batchGetProfiles(ids: userIds)) ?? []
            let profiles = Dictionary(uniqueKeysWithValues: fetchedProfiles.map { ($0.id, $0) })

            await MainActor.run {
                self.trackReviews = reviews
                self.reviewProfiles = profiles
                self.isLoadingReviews = false
            }
        } catch {
            print("Failed to load track reviews: \(error)")
            await MainActor.run { self.isLoadingReviews = false }
        }
    }
    
    // MARK: - Album
    private func loadAlbum() async {
        guard let collectionId = track.collectionId else { return }
        if let fetched = try? await MusicService.shared.fetchAlbum(collectionId: collectionId) {
            await MainActor.run { self.album = fetched }
        }
    }

    // MARK: - Audio
    private func toggleAudio() {
        audioManager.toggle(trackId: track.id, previewUrl: track.previewUrl)
    }
    
    private func shareTrack() {
        let text = "\(track.title) by \(track.artist)"
        var items: [Any] = [text]
        if let spotifyLink = track.spotifyDeepLink {
            items.append(spotifyLink)
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Track Review Card

struct TrackReviewCard: View {
    let review: Review
    let profile: Profile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: review.vibeColor).opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Text(String((profile?.username ?? "U").prefix(1)).uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    } else {
                        Text(String((profile?.username ?? "U").prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.username ?? "Anonymous")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text(review.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#FFCC00"))
                    Text(String(format: "%.1f", Double(review.rating) / 2.0))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                
                Circle()
                    .fill(Color(hex: review.vibeColor))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color(hex: review.vibeColor).opacity(0.6), radius: 4)
            }
            
            if let text = review.reviewText, !text.isEmpty {
                // Masked on read: rows written before the profanity filter are still in the DB.
                Text(ProfanityFilter.masked(text))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        // Long press to report or block — the community list is where an offensive review is
        // most likely to be seen, so the action has to be reachable from here too.
        .moderationActions(
            contentType: .songReview,
            contentRef: review.id.uuidString,
            authorId: review.userId,
            authorUsername: profile?.username,
            reportedText: review.reviewText
        )
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        TrackDetailView(
            track: Track(
                id: 1488408568,
                title: "Blinding Lights",
                artist: "The Weeknd",
                artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/a4/a04da453-3a4b-851b-5813-2b20aa8024e0/source/100x100bb.jpg",
                previewUrl: nil
            )
        )
    }
}
