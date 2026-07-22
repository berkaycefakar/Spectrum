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
    @State private var userAlbumReview: AlbumReview?
    @State private var communityReviews: [AlbumReview] = []
    @State private var showLogSheet = false
    
    private var communityAverageRating: Double {
        guard !communityReviews.isEmpty else { return 0 }
        let sum = communityReviews.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(communityReviews.count) / 2.0 // 0-10 -> 0-5
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
            await loadTracks()
            await loadCommunityReviews()
            await loadUserAlbumReview()
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
                .shadow(color: Color(hex: "#FF00FF").opacity(0.5), radius: 20)
            }
            
            VStack(spacing: 4) {
                Text(album.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Topluluk puanları (community)
    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            HStack(spacing: 0) {
                // Rating
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "#FFCC00"))
                        Text(String(format: "%.1f", communityAverageRating))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    Text("avg rating")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 1, height: 36)

                // Count
                VStack(spacing: 6) {
                    Text("\(communityReviews.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("ratings")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal)
        }
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
                        .disabled(isSaving || albumRating <= 0)
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
        guard let user = try? await SupabaseManager.shared.getCurrentUser() else { return }
        do {
            let reviews = try await SupabaseManager.shared.getUserAlbumReviews(userId: user.id)
            if let review = reviews.first(where: { $0.itunesCollectionId == album.id }) {
                await MainActor.run {
                    self.userAlbumReview = review
                    self.albumRating = Double(review.rating) / 2.0
                    self.reviewText = review.reviewText ?? ""
                }
            }
        } catch {
            print("Failed to load user album review: \(error)")
        }
    }
    
    private func saveAlbumRating() {
        guard !isSaving, albumRating > 0 else { return }
        isSaving = true
        Task {
            do {
                let storedRating = Int((albumRating * 2).rounded())
                try await SupabaseManager.shared.saveAlbumReview(
                    collectionId: album.id,
                    rating: storedRating,
                    text: reviewText,
                    vibeColor: "#FFCC00"
                )
                await loadUserAlbumReview()
                await loadCommunityReviews()
                await MainActor.run {
                    self.isSaving = false
                    self.showLogSheet = false
                }
            } catch {
                await MainActor.run { self.isSaving = false }
                print("Failed to save album rating: \(error)")
            }
        }
    }
}
