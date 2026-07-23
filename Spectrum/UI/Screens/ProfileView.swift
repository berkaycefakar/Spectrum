import SwiftUI
import Supabase

struct ProfileView: View {
    @StateObject private var sessionStore = SessionStore.shared
    
    @State private var profile: Profile?
    @State private var reviews: [Review] = []
    @State private var albumReviews: [AlbumReview] = []
    // NOTE: Artist rating feature is disabled for now.
    // @State private var artistReviews: [ArtistReview] = []
    @State private var artistReviews: [ArtistReview] = []
    @State private var tracks: [Int64: Track] = [:] // Cache for tracks
    @State private var albums: [Int64: Album] = [:] // Cache for albums
    @State private var followers: [Profile] = []
    @State private var following: [Profile] = []
    @State private var showFollowersSheet = false
    @State private var showFollowingSheet = false
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showLogoutAlert = false
    @State private var selectedCategory: ProfileCategory = .songs
    
    // Computed Stats
    var vibeStats: [(color: String, percentage: CGFloat, label: String)] {
        guard !reviews.isEmpty else { return [] }
        
        let total = CGFloat(reviews.count)
        var counts: [String: Int] = [:]
        
        for review in reviews {
            counts[review.vibeColor, default: 0] += 1
        }
        
        // Sort by count and take top 5
        let sorted = counts.sorted { $0.value > $1.value }.prefix(5)
        
        return sorted.map { (color, count) in
            (color: color, percentage: CGFloat(count) / total, label: "")
        }
    }
    
    // Average rating across all reviews (songs only for now)
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count) / 2.0 // Convert 0-10 to 0-5
    }
    
    // Sorted reviews by rating (highest first)
    var sortedReviews: [Review] {
        reviews.sorted { $0.rating > $1.rating }
    }
    
    // Sorted album reviews by rating (highest first)
    var sortedAlbumReviews: [AlbumReview] {
        albumReviews.sorted { $0.rating > $1.rating }
    }
    
    // Sorted artist reviews by rating (highest first)
    var sortedArtistReviews: [ArtistReview] {
        artistReviews.sorted { $0.rating > $1.rating }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Ambient Glow based on top vibe
                if let topVibe = vibeStats.first?.color {
                    Circle()
                        .fill(Color(hex: topVibe).opacity(0.3))
                        .frame(width: 300, height: 300)
                        .blur(radius: 100)
                        .offset(x: -100, y: -200)
                        .animation(.easeInOut, value: topVibe)
                }
                
                ScrollView {
                    VStack(spacing: 30) {
                        // 1. Profile Header with Stats
                        if let profile = profile {
                            ProfileHeader(
                                profile: profile,
                                totalLogs: reviews.count,
                                averageRating: averageRating,
                                followersCount: followers.count,
                                followingCount: following.count,
                                onEditTapped: {
                                    showEditProfile = true
                                },
                                onFollowersTapped: {
                                    showFollowersSheet = true
                                },
                                onFollowingTapped: {
                                    showFollowingSheet = true
                                }
                            )
                        } else if isLoading {
                            ProgressView().tint(.white)
                        }
                        
                        // 2. Spectrum Visualization
                        if !vibeStats.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Spectrum")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                SpectrumBarChart(stats: vibeStats)
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Category Tabs & Logs
                        VStack(alignment: .leading, spacing: 16) {
                            // Category Selector
                            HStack(spacing: 0) {
                                ProfileCategoryButton(
                                    title: "Songs",
                                    count: reviews.count,
                                    isSelected: selectedCategory == .songs
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = .songs
                                    }
                                }
                                
                                ProfileCategoryButton(
                                    title: "Albums",
                                    count: albumReviews.count,
                                    isSelected: selectedCategory == .albums
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = .albums
                                    }
                                }
                                
                                ProfileCategoryButton(
                                    title: "Artists",
                                    count: artistReviews.count,
                                    isSelected: selectedCategory == .artists
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = .artists
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Content based on selected category
                            if isLoading {
                                ProgressView().tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                categoryContent
                            }
                        }
                        .padding(.horizontal)
                        
                        // 4. Account Actions Section
                        AccountActionsSection(
                            onEditProfile: {
                                showEditProfile = true
                            },
                            onSettings: {
                                showSettings = true
                            },
                            onLogout: {
                                showLogoutAlert = true
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100) // Space for TabBar
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadProfileData()
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = profile {
                    EditProfileView(
                        isPresented: $showEditProfile,
                        currentUsername: profile.username ?? "",
                        currentBio: profile.bio ?? "",
                        currentAvatarUrl: profile.avatarUrl,
                        onSave: {
                            Task { await loadProfileData() } // Refresh after save
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(isPresented: $showSettings, onLogout: {
                    Task { await sessionStore.signOut() }
                })
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFollowersSheet) {
                FollowersFollowingListView(
                    title: "Followers",
                    profiles: followers
                )
            }
            .sheet(isPresented: $showFollowingSheet) {
                FollowersFollowingListView(
                    title: "Following",
                    profiles: following
                )
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    Task {
                        await sessionStore.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
    
    // MARK: - Category Content
    
    @ViewBuilder
    private var categoryContent: some View {
        switch selectedCategory {
        case .songs:
            if sortedReviews.isEmpty {
                emptyStateView(message: "No songs logged yet")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(sortedReviews) { review in
                        if let track = tracks[review.itunesTrackId] {
                            NavigationLink(destination: LogDetailView(track: track, review: review, isOwner: true, onChanged: {
                                Task { await loadProfileData() }
                            })) {
                                AlbumGridItem(track: track, vibeColor: Color(hex: review.vibeColor))
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.05))
                                .frame(height: 200)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                }
            }
            
        case .albums:
            if sortedAlbumReviews.isEmpty {
                emptyStateView(message: "No albums rated yet")
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(sortedAlbumReviews) { review in
                        if let album = albums[review.itunesCollectionId] {
                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                AlbumGridItemView(
                                    title: album.title,
                                    subtitle: album.artist,
                                    artworkUrl: album.artworkUrl600,
                                    vibeColor: Color(hex: review.vibeColor),
                                    rating: Double(review.rating) / 2.0
                                )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.05))
                                .frame(height: 200)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                }
            }
            
        case .artists:
            if sortedArtistReviews.isEmpty {
                emptyStateView(message: "No artists rated yet")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sortedArtistReviews) { review in
                        ArtistReviewRow(review: review)
                    }
                }
            }
        }
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            
            Text(message)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func loadProfileData() async {
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            guard let currentUser = try await SupabaseManager.shared.getCurrentUser() else { return }
            
            // 1. Fetch Profile
            let profileData = try await SupabaseManager.shared.getProfile(userId: currentUser.id)
            
            // 2. Fetch song reviews (required table: reviews)
            let reviews = try await SupabaseManager.shared.getUserReviews(userId: currentUser.id)
            
            // 3. Fetch album reviews only if table exists (optional; use [] on error)
            let albumReviews: [AlbumReview] = (try? await SupabaseManager.shared.getUserAlbumReviews(userId: currentUser.id)) ?? []
            // Optional like album reviews: if the artist_reviews table is missing we show
            // an empty tab rather than failing the whole profile load.
            let artistReviews: [ArtistReview]
            do {
                artistReviews = try await SupabaseManager.shared.getUserArtistReviews(userId: currentUser.id)
            } catch {
                print("Profile: failed to load artist reviews:", error)
                artistReviews = []
            }
            
            // 4. Followers / Following lists
            let followers = (try? await SupabaseManager.shared.getFollowers(userId: currentUser.id)) ?? []
            let following = (try? await SupabaseManager.shared.getFollowing(userId: currentUser.id)) ?? []
            
            await MainActor.run {
                self.profile = profileData
                self.reviews = reviews
                self.albumReviews = albumReviews
                self.artistReviews = artistReviews
                self.followers = followers
                self.following = following
            }
            
            // 5. Fetch track + album details in two batched requests (was one-by-one).
            let trackIds = Array(Set(reviews.map { $0.itunesTrackId }))
            let albumIds = Array(Set(albumReviews.map { $0.itunesCollectionId }))
            let fetchedTracks = await MusicService.shared.fetchTracks(ids: trackIds)
            let fetchedAlbums = await MusicService.shared.fetchAlbums(ids: albumIds)
            await MainActor.run {
                for (id, track) in fetchedTracks { self.tracks[id] = track }
                for (id, album) in fetchedAlbums { self.albums[id] = album }
            }
            
        } catch {
            print("Error loading profile: \(error)")
        }
    }
}

// MARK: - Profile Category

enum ProfileCategory {
    case songs
    case albums
    case artists
}

// MARK: - Profile Category Button

struct ProfileCategoryButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color(hex: "#FF00FF") : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
    }
}

// MARK: - Album Grid Item View (Reusable)

struct AlbumGridItemView: View {
    let title: String
    let subtitle: String
    let artworkUrl: URL?
    let vibeColor: Color
    /// 0–5 display (optional); when set, shows star rating below subtitle.
    var rating: Double? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(vibeColor.opacity(0.3))
                    .blur(radius: 20)
                    .offset(y: 10)
                
                AsyncImage(url: artworkUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [vibeColor.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                
                if let rating = rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#FFCC00"))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(width: 160)
    }
}

// MARK: - Artist Review Row

struct ArtistReviewRow: View {
    let review: ArtistReview

    var body: some View {
        NavigationLink(destination: ArtistDetailView(artistName: review.artistName)) {
            HStack(spacing: 16) {
                // Artist icon/avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color(hex: review.vibeColor).opacity(0.3))
                        .frame(width: 50, height: 50)

                    Text(String(review.artistName.prefix(1)).uppercased())
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: review.vibeColor))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(review.artistName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= (review.rating / 2) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: review.vibeColor))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
