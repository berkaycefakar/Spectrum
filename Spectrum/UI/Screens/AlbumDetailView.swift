import SwiftUI
import Supabase

/// Album sayfası: önce bilgi + topluluk puanları + parça listesi; puanlama/yorum ayrı sheet'te (Log).
struct AlbumDetailView: View {
    let album: Album
    
    @State private var tracks: [Track] = []
    @State private var tracksLoading = true
    @State private var albumRating: Double = 0
    @State private var reviewText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var userAlbumReview: AlbumReview?
    @State private var communityReviews: [AlbumReview] = []
    @State private var showLogSheet = false
    @State private var artworkColor: ArtworkColor = .placeholder
    /// Album logs used to hard-code gold, which made "what vibe did people give this?"
    /// unanswerable. Users pick it from the prism now, same as songs.
    @State private var selectedVibeHex: String = "#FFCC00"
    @State private var hasPickedVibe = false

    private var communityStats: CommunityStats {
        CommunityStats(
            ratings: communityReviews.map(\.rating),
            vibeHexes: communityReviews.map(\.vibeColor)
        )
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    communitySection
                    trackListSection
                    rateButton
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Four independent loads (artwork colour, track list, community ratings, the
            // user's own rating). Run in parallel — sequentially the page took as long as
            // all four combined before anything below the hero appeared.
            async let colorLoad: ArtworkColor = ArtworkColorLoader.shared.color(for: album.artworkUrl600)
            async let trackLoad: Void = loadTracks()
            async let communityLoad: Void = loadCommunityReviews()
            async let ownReviewLoad: Void = loadUserAlbumReview()

            let color = await colorLoad
            _ = await (trackLoad, communityLoad, ownReviewLoad)

            artworkColor = color
            // Pre-select the palette entry closest to the cover, but only when the cover
            // actually has a colour — a monochrome sleeve would just be a guess — and never
            // over the top of the vibe the user already saved.
            if !hasPickedVibe, !color.isNeutral {
                selectedVibeHex = VibePalette.nearest(to: color.accent)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            albumLogSheet
        }
    }
    
    // MARK: - Hero (albüm bilgisi)
    private var heroSection: some View {
        VStack(spacing: 16) {
            if let url = album.artworkUrl600 {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: artworkColor.accent.opacity(0.5), radius: 20)
                .animation(.easeInOut(duration: 0.45), value: artworkColor.accent)
            }
            
            VStack(spacing: 6) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Tappable: album → artist page.
                NavigationLink(destination: ArtistDetailView(artistName: album.artist, artistId: album.artistId)) {
                    HStack(spacing: 5) {
                        Text(album.artist)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Topluluk puanları (community)
    private var communitySection: some View {
        CommunityStatsCard(stats: communityStats)
            .padding(.horizontal)
    }
    
    // MARK: - Parça listesi
    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracks")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)
            
            if tracksLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        NavigationLink(destination: TrackDetailView(track: track)) {
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    // Track number
                                    Text("\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white.opacity(0.35))
                                        .frame(width: 24)

                                    // Artwork thumbnail
                                    AsyncImage(url: track.artworkUrl600) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.white.opacity(0.1)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.25))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if index < tracks.count - 1 {
                                    Divider()
                                        .background(.white.opacity(0.06))
                                        .padding(.leading, 54)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Rate / Log butonu (sheet açar)
    private var rateButton: some View {
        Button {
            showLogSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: userAlbumReview != nil ? "star.circle.fill" : "star.circle")
                    .font(.system(size: 18, weight: .semibold))
                Text(userAlbumReview != nil ? "Edit your rating" : "Rate this album")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FFCC00"), Color(hex: "#FFB800")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color(hex: "#FFCC00").opacity(0.35), radius: 12, y: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Sheet: puan + yorum (Log)
    private var albumLogSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Your rating")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            RatingLabel(rating: albumRating, maxRating: 5, accentColor: Color(hex: "#FFCC00"))
                        }
                        
                        SpectrumRatingControl(
                            rating: $albumRating,
                            accentColor: Color(hex: "#FFCC00")
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your vibe")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))

                            SpectrumPrismPicker(
                                selectedHex: $selectedVibeHex,
                                vibeColors: VibePalette.colors,
                                onManualPick: { hasPickedVibe = true },
                                beamHeight: 130
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your thoughts")
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))
                            TextField("Add a short review...", text: $reviewText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#FFCC00").opacity(0.35), lineWidth: 1)
                                )
                        }
                        
                        if isSaving {
                            HStack {
                                ProgressView().tint(.white)
                                Text("Saving...")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        } else if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                            }
                            .font(.footnote)
                            .foregroundStyle(Color(hex: "#FF3B30"))
                        } else if userAlbumReview != nil {
                            Text("Saved")
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "#FFCC00"))
                        }

                        Button {
                            saveAlbumRating()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#FFCC00"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        // Deliberately NOT disabled when the rating is empty: a dead button
                        // told the user nothing. Tapping it now explains what's missing.
                        .disabled(isSaving)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(album.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showLogSheet = false
                    }
                    .foregroundStyle(Color(hex: "#FFCC00"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Sheet açıldığında mevcut değerler zaten yüklü (loadUserAlbumReview)
        }
    }
    
    private func loadTracks() async {
        do {
            let fetched = try await MusicService.shared.fetchTracksForAlbum(albumId: album.id)
            await MainActor.run {
                self.tracks = fetched
                self.tracksLoading = false
            }
        } catch {
            await MainActor.run { self.tracksLoading = false }
            print("Failed to load album tracks: \(error)")
        }
    }
    
    private func loadCommunityReviews() async {
        guard let list = try? await SupabaseManager.shared.getAlbumReviews(collectionId: album.id) else { return }
        await MainActor.run { self.communityReviews = list }
    }
    
    private func loadUserAlbumReview() async {
        do {
            guard let review = try await SupabaseManager.shared.getUserAlbumReview(collectionId: album.id) else { return }
            await MainActor.run {
                self.userAlbumReview = review
                self.albumRating = Double(review.rating) / 2.0
                self.reviewText = review.reviewText ?? ""
                // Their own saved vibe wins over the artwork guess.
                self.selectedVibeHex = VibePalette.snap(review.vibeColor)
                self.hasPickedVibe = true
            }
        } catch {
            print("Failed to load user album review: \(error)")
        }
    }
    
    private func saveAlbumRating() {
        guard !isSaving else { return }

        // Picking only a vibe used to hit the `albumRating > 0` guard and return silently.
        guard albumRating > 0 else {
            errorMessage = "Add a rating before saving."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let storedRating = Int((albumRating * 2).rounded())
                try await SupabaseManager.shared.saveAlbumReview(
                    collectionId: album.id,
                    rating: storedRating,
                    text: reviewText,
                    vibeColor: selectedVibeHex
                )
                await loadUserAlbumReview()
                await loadCommunityReviews()
                await MainActor.run {
                    self.isSaving = false
                    self.showLogSheet = false
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Couldn't save: \(error.localizedDescription)"
                }
                print("Failed to save album rating: \(error)")
            }
        }
    }
}
