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
    // Artist reviews only store a name, so photos have to be resolved from MusicKit.
    @State private var artistBriefs: [String: ArtistBrief] = [:]
    @State private var followers: [Profile] = []
    @State private var following: [Profile] = []
    @State private var showFollowersSheet = false
    @State private var showFollowingSheet = false
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showLogoutAlert = false
    @State private var selectedCategory: ProfileCategory = .songs
    /// Lifetime totals for the tab labels and the header chart. The lists below are paged,
    /// so `reviews.count` now means "loaded so far" and can't be shown to the user.
    @State private var totals: (songs: Int, albums: Int, artists: Int) = (0, 0, 0)
    @State private var summary: SupabaseManager.UserLogSummary = .empty
    /// Per-category paging cursor. Each tab loads independently — opening Albums shouldn't
    /// pay for the pages Songs has already scrolled through.
    @State private var loadedMore: Set<ProfileCategory> = []
    @State private var isLoadingMore = false
    @State private var showStats = false
    @StateObject private var reselection = TabReselectionState.shared
    /// Value-based navigation so tapping Profile while already on it returns to the top.
    @State private var path = NavigationPath()
    
    // Computed Stats — over the user's whole history, not the loaded page.
    var vibeStats: [(color: String, percentage: CGFloat, label: String)] {
        guard !summary.vibeColors.isEmpty else { return [] }

        let total = CGFloat(summary.vibeColors.count)
        var counts: [String: Int] = [:]

        for hex in summary.vibeColors {
            counts[hex, default: 0] += 1
        }

        // Top five, with the hex breaking ties so the bars don't reshuffle between loads.
        let sorted = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(5)

        return sorted.map { (color, count) in
            (color: color, percentage: CGFloat(count) / total, label: "")
        }
    }

    // Average rating across all song logs.
    var averageRating: Double { summary.averageRating }
    
    // Best-rated first — the profile grid is a "favourites" wall, not a diary — with the most
    // recent log breaking ties. The tie-break matters: `sorted(by:)` is not a stable sort, so
    // ranking on rating alone let equally-rated logs swap positions on every reload.
    // The three lists arrive already ordered — rating first, then recency, then id. They used
    // to be re-sorted here, which was fine for a single unbounded fetch but breaks under
    // paging: re-sorting only the rows loaded so far lets a five-star log from page two jump
    // above a three-star one the user is already looking at.
    var sortedReviews: [Review] { reviews }
    var sortedAlbumReviews: [AlbumReview] { albumReviews }
    var sortedArtistReviews: [ArtistReview] { artistReviews }

    var body: some View {
        NavigationStack(path: $path) {
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
                            Button {
                                showStats = true
                            } label: {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Your Spectrum")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        // The bar chart alone gave no hint there was more
                                        // behind it; people tapped it and nothing happened.
                                        HStack(spacing: 3) {
                                            Text("See all")
                                                .font(.caption.weight(.semibold))
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundStyle(Color(hex: "#FF00FF"))
                                    }

                                    SpectrumBarChart(stats: vibeStats)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Your Spectrum, see full statistics")
                            .padding(.horizontal)
                        }
                        
                        // 3. Lists
                        if let profileId = profile?.id {
                            ProfileListsSection(userId: profileId, isOwner: true)
                                .padding(.horizontal)
                        }

                        // 4. Category Tabs & Logs
                        VStack(alignment: .leading, spacing: 16) {
                            // Category Selector
                            HStack(spacing: 0) {
                                ProfileCategoryButton(
                                    title: "Songs",
                                    count: totals.songs,
                                    isSelected: selectedCategory == .songs
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = .songs
                                    }
                                }
                                
                                ProfileCategoryButton(
                                    title: "Albums",
                                    count: totals.albums,
                                    isSelected: selectedCategory == .albums
                                ) {
                                    withAnimation(.spring()) {
                                        selectedCategory = .albums
                                    }
                                }
                                
                                ProfileCategoryButton(
                                    title: "Artists",
                                    count: totals.artists,
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

                                if hasMoreInCategory {
                                    // Scrolling it into view is what starts the next page.
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 24)
                                        .task(id: pagingToken) { await loadMoreInCategory() }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 5. Account Actions Section
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
                .tracksTabBarScroll(tab: 3)
            }
            .appRouteDestinations(onLogChanged: { Task { await loadProfileData() } })
            .navigationBarHidden(true)
            .task {
                await loadProfileData()
            }
            .sheet(isPresented: $showStats) {
                ListeningStatsView(
                    summary: summary,
                    albumCount: totals.albums,
                    artistCount: totals.artists
                )
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
        .onChange(of: reselection.token(for: 3)) { _, _ in
            path = NavigationPath()
        }
    }
    
    // MARK: - Paging

    private var loadedCount: Int {
        switch selectedCategory {
        case .songs: reviews.count
        case .albums: albumReviews.count
        case .artists: artistReviews.count
        }
    }

    private var totalCount: Int {
        switch selectedCategory {
        case .songs: totals.songs
        case .albums: totals.albums
        case .artists: totals.artists
        }
    }

    private var hasMoreInCategory: Bool { loadedCount < totalCount }

    /// Identity for the spinner's `.task`. Changing tab or growing the list re-arms it;
    /// anything else (a redraw, a scroll) leaves it alone.
    private var pagingToken: String { "\(selectedCategory)-\(loadedCount)" }

    /// Appends the next page of whichever tab is open.
    private func loadMoreInCategory() async {
        guard hasMoreInCategory, !isLoadingMore else { return }
        guard let userId = try? await SupabaseManager.shared.getCurrentUser()?.id else { return }

        await MainActor.run { self.isLoadingMore = true }
        defer { Task { @MainActor in self.isLoadingMore = false } }

        let offset = loadedCount

        switch selectedCategory {
        case .songs:
            let page = (try? await SupabaseManager.shared.getUserReviews(userId: userId, offset: offset)) ?? []
            let tracksById = await MusicService.shared.fetchTracks(ids: Array(Set(page.map(\.itunesTrackId))))
            await MainActor.run {
                // De-duplicated by id: a log saved while the user was scrolling shifts every
                // later row down by one, and the boundary row would otherwise arrive twice.
                let known = Set(self.reviews.map(\.id))
                self.reviews.append(contentsOf: page.filter { !known.contains($0.id) })
                for (id, track) in tracksById { self.tracks[id] = track }
            }

        case .albums:
            let page = (try? await SupabaseManager.shared.getUserAlbumReviews(userId: userId, offset: offset)) ?? []
            let albumsById = await MusicService.shared.fetchAlbums(ids: Array(Set(page.map(\.itunesCollectionId))))
            await MainActor.run {
                let known = Set(self.albumReviews.map(\.id))
                self.albumReviews.append(contentsOf: page.filter { !known.contains($0.id) })
                for (id, album) in albumsById { self.albums[id] = album }
            }

        case .artists:
            let page = (try? await SupabaseManager.shared.getUserArtistReviews(userId: userId, offset: offset)) ?? []
            let briefs = await MusicService.shared.fetchArtistBriefs(names: page.map(\.artistName))
            await MainActor.run {
                let known = Set(self.artistReviews.map(\.id))
                self.artistReviews.append(contentsOf: page.filter { !known.contains($0.id) })
                for (name, brief) in briefs { self.artistBriefs[name] = brief }
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
                            NavigationLink(value: AppRoute.log(track: track, review: review, isOwner: true)) {
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
                            NavigationLink(value: AppRoute.album(album)) {
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
                        ArtistReviewRow(review: review, brief: artistBriefs[review.artistName])
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
            
            // 3. Album, artist, follower and following lists are independent of each other —
            //    fetch them concurrently rather than as four chained round-trips. Each is
            //    optional: a missing table shows an empty tab instead of failing the load.
            async let albumReviewsLoad = (try? await SupabaseManager.shared.getUserAlbumReviews(userId: currentUser.id)) ?? []
            async let artistReviewsLoad = (try? await SupabaseManager.shared.getUserArtistReviews(userId: currentUser.id)) ?? []
            async let followersLoad = (try? await SupabaseManager.shared.getFollowers(userId: currentUser.id)) ?? []
            async let followingLoad = (try? await SupabaseManager.shared.getFollowing(userId: currentUser.id)) ?? []
            // Lifetime totals and the vibe/rating summary: the lists are paged now, so the
            // tab counts and the header chart can no longer be derived from them.
            async let totalsLoad = SupabaseManager.shared.countUserLogs(userId: currentUser.id)
            async let summaryLoad = SupabaseManager.shared.fetchUserLogSummary(userId: currentUser.id)

            let albumReviews = await albumReviewsLoad
            let artistReviews = await artistReviewsLoad
            let followers = await followersLoad
            let following = await followingLoad
            let totals = await totalsLoad
            let summary = await summaryLoad

            await MainActor.run {
                self.profile = profileData
                self.reviews = reviews
                self.albumReviews = albumReviews
                self.artistReviews = artistReviews
                self.followers = followers
                self.following = following
                self.totals = totals
                self.summary = summary
            }
            
            // 5. Fetch track + album details in two batched requests (was one-by-one),
            // plus artist photos, which only exist in MusicKit (artist_reviews stores a name).
            let trackIds = Array(Set(reviews.map { $0.itunesTrackId }))
            let albumIds = Array(Set(albumReviews.map { $0.itunesCollectionId }))
            let artistNames = artistReviews.map { $0.artistName }
            async let tracksLoad = MusicService.shared.fetchTracks(ids: trackIds)
            async let albumsLoad = MusicService.shared.fetchAlbums(ids: albumIds)
            async let briefsLoad = MusicService.shared.fetchArtistBriefs(names: artistNames)

            let fetchedTracks = await tracksLoad
            let fetchedAlbums = await albumsLoad
            let fetchedArtists = await briefsLoad
            await MainActor.run {
                for (id, track) in fetchedTracks { self.tracks[id] = track }
                for (id, album) in fetchedAlbums { self.albums[id] = album }
                for (name, brief) in fetchedArtists { self.artistBriefs[name] = brief }
            }
            
        } catch {
            debugLog("Error loading profile: \(error)")
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
    /// Photo + catalog id resolved from MusicKit; nil until the lookup lands (or if it fails).
    var brief: ArtistBrief? = nil

    /// Full, half or empty star for position `index`, from the 0–10 stored rating.
    private func starSymbol(for index: Int) -> String {
        let doubled = review.rating
        if doubled >= index * 2 { return "star.fill" }
        if doubled == index * 2 - 1 { return "star.leadinghalf.filled" }
        return "star"
    }

    var body: some View {
        NavigationLink(value: AppRoute.artist(name: review.artistName, id: brief?.id)) {
            HStack(spacing: 16) {
                artistAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(review.artistName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    // `rating` is stored 0–10 so half stars can be expressed. Dividing the
                    // integer by 2 threw the half away, so a 3.5 rating drew as 3 flat — the
                    // one place in the app where a user's own rating was displayed wrong.
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: starSymbol(for: index))
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

    /// The artist's photo, falling back to the initial-on-vibe-colour badge while the MusicKit
    /// lookup is in flight or when the artist has no press shot.
    private var artistAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: review.vibeColor).opacity(0.3))

            if let url = brief?.artworkUrl {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        initialBadge
                    }
                }
                .clipShape(Circle())
            } else {
                initialBadge
            }
        }
        .frame(width: 50, height: 50)
        .overlay(
            Circle().stroke(Color(hex: review.vibeColor).opacity(0.45), lineWidth: 1.5)
        )
    }

    private var initialBadge: some View {
        Text(String(review.artistName.prefix(1)).uppercased())
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(Color(hex: review.vibeColor))
    }
}
