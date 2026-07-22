import SwiftUI

struct TrackDetailView: View {
    let track: Track

    @ObservedObject private var audioManager = AudioManager.shared
    @State private var showAddLog = false
    @State private var dominantColor: Color = Color(hex: "#FF00FF")

    private var isPlaying: Bool {
        audioManager.isTrackPlaying(track.id)
    }
    
    @State private var trackReviews: [Review] = []
    @State private var reviewProfiles: [UUID: Profile] = [:]
    @State private var isLoadingReviews = true
    @State private var album: Album?
    
    private var averageRating: Double {
        guard !trackReviews.isEmpty else { return 0 }
        let total = trackReviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(trackReviews.count) / 2.0
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

                        if !trackReviews.isEmpty {
                            statsBar
                        }

                        reviewsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
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
            await loadTrackReviews()
            await loadAlbum()
        }
        .onDisappear {
            if audioManager.isTrackPlaying(track.id) {
                audioManager.stop()
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Blurred background — must be clipped to frame
            GeometryReader { geo in
                AsyncImage(url: track.artworkUrl600) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: 420)
                    } else {
                        Color.gray.opacity(0.3)
                            .frame(width: geo.size.width, height: 420)
                    }
                }
                .clipped()
                .blur(radius: 50)
                .overlay(Color.black.opacity(0.4))
            }
            .frame(height: 420)
            .clipped()

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

                    Text(track.artist)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 30)
            .padding(.top, 50)
        }
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FF00FF"), Color(hex: "#8B00FF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#FF00FF").opacity(0.4), radius: 12, y: 4)
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
                                        colors: [Color(hex: "#00FFFF").opacity(0.6), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#00FFFF"))
                }
                .frame(width: 48, height: 48)
                .shadow(color: Color(hex: "#00FFFF").opacity(0.3), radius: 8)
            }

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
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color(hex: "#FF00FF"))
                Text("\(trackReviews.count) logs")
            }
            
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color(hex: "#FFCC00"))
                Text(String(format: "%.1f", averageRating) + " avg")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Reviews Section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Reviews")
                .font(.headline)
                .foregroundStyle(.white)
            
            if isLoadingReviews {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if trackReviews.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No reviews yet — be the first!")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
    private func loadTrackReviews() async {
        do {
            let reviews = try await SupabaseManager.shared.getTrackReviews(trackId: Int64(track.id))
            
            var profiles: [UUID: Profile] = [:]
            for uid in Set(reviews.map { $0.userId }) {
                if let p = try? await SupabaseManager.shared.getProfile(userId: uid) {
                    profiles[uid] = p
                }
            }
            
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
                Text(text)
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
