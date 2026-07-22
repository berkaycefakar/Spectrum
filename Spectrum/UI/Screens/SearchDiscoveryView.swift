import SwiftUI
import Supabase

/// Search & Discovery Screen
/// Purpose: Find songs to log with visual recommendations before searching
struct SearchDiscoveryView: View {
    @State private var searchText = ""
    @State private var trackResults: [Track] = []
    @State private var albumResults: [Album] = []
    @State private var artistResults: [Artist] = []
    @State private var userResults: [Profile] = []
    @State private var selectedTrack: Track?
    @State private var isSearching = false
    @State private var showAllTrackResults = false
    @State private var showAllAlbumResults = false
    @State private var showAllArtistResults = false
    @State private var searchTask: Task<Void, Never>?
    
    // Trending Vibes - Mock data (TODO: Replace with backend data)
    let trendingVibes = [
        TrendingVibe(name: "Late Night Drive", gradient: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")], icon: "car.fill"),
        TrendingVibe(name: "Gym Hype", gradient: [Color(hex: "#ff416c"), Color(hex: "#ff4b2b")], icon: "bolt.fill"),
        TrendingVibe(name: "Heartbreak", gradient: [Color(hex: "#667eea"), Color(hex: "#764ba2")], icon: "heart.slash.fill"),
        TrendingVibe(name: "Chill Vibes", gradient: [Color(hex: "#11998e"), Color(hex: "#38ef7d")], icon: "leaf.fill"),
        TrendingVibe(name: "Party Mode", gradient: [Color(hex: "#f12711"), Color(hex: "#f5af19")], icon: "sparkles"),
        TrendingVibe(name: "Focus Flow", gradient: [Color(hex: "#4776E6"), Color(hex: "#8E54E9")], icon: "brain.head.profile")
    ]
    
    // Sample tracks for discovery - Mock data (TODO: Replace with backend recommendations)
    @State private var discoverTracks: [Track] = []
    
    // NOTE: iTunes tarafında doğrudan "artist entity" araması/sonucu kullanmadığımız için
    // Artists sekmesini şimdilik devre dışı bıraktık.
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Ambient glow
                Circle()
                    .fill(Color(hex: "#FF00FF").opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -150, y: -300)
                
                Circle()
                    .fill(Color(hex: "#00FFFF").opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: 150, y: 100)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        Text("Discover")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                        
                        // Floating Search Bar
                        searchBar
                            .padding(.horizontal)
                        
                        if searchText.isEmpty {
                            // Show discovery content when not searching
                            DiscoveryContentView(
                                trendingVibes: trendingVibes,
                                discoverTracks: discoverTracks,
                                searchText: $searchText,
                                selectedTrack: $selectedTrack
                            )
                        } else {
                            // Show search results
                            searchResultsView
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadDiscoverTracks()
            }
            .sheet(item: $selectedTrack) { track in
                AddLogView(track: track, isPresented: Binding(
                    get: { selectedTrack != nil },
                    set: { if !$0 { selectedTrack = nil } }
                ))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            
            TextField("Songs, albums, artists, users...", text: $searchText)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    Task { await performSearch(query: searchText) }
                }
                .onChange(of: searchText) { oldValue, newValue in
                    searchTask?.cancel()
                    guard newValue.count >= 2 else {
                        trackResults = []
                        albumResults = []
                        artistResults = []
                        userResults = []
                        isSearching = false
                        return
                    }
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard !Task.isCancelled else { return }
                        await performSearch(query: newValue)
                    }
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    trackResults = []
                    albumResults = []
                    artistResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .padding(.top, 40)
            } else if trackResults.isEmpty && albumResults.isEmpty && artistResults.isEmpty && userResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No tracks found")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                Text("\(trackResults.count) Songs • \(albumResults.count) Albums • \(artistResults.count) Artists • \(userResults.count) Users")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal)
                
                // Tracks
                if !trackResults.isEmpty {
                    Text("Songs")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    let tracksToShow = showAllTrackResults ? trackResults : Array(trackResults.prefix(5))
                    
                    LazyVStack(spacing: 12) {
                        ForEach(tracksToShow) { track in
                            QuickAddTrackRow(track: track) {
                                selectedTrack = track
                            }
                        }
                        
                        if trackResults.count > 5 {
                            Button(showAllTrackResults ? "Show less" : "See more") {
                                withAnimation(.spring()) {
                                    showAllTrackResults.toggle()
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#FF00FF"))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Albums
                if !albumResults.isEmpty {
                    Text("Albums")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    let albumsToShow = showAllAlbumResults ? albumResults : Array(albumResults.prefix(5))
                    
                    LazyVStack(spacing: 12) {
                        ForEach(albumsToShow) { album in
                            AlbumRow(album: album)
                        }
                        
                        if albumResults.count > 5 {
                            Button(showAllAlbumResults ? "Show less" : "See more") {
                                withAnimation(.spring()) {
                                    showAllAlbumResults.toggle()
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#FF00FF"))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Artists
                if !artistResults.isEmpty {
                    Text("Artists")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    let artistsToShow = showAllArtistResults ? artistResults : Array(artistResults.prefix(5))

                    LazyVStack(spacing: 12) {
                        ForEach(artistsToShow) { artist in
                            ArtistRow(artist: artist)
                        }

                        if artistResults.count > 5 {
                            Button(showAllArtistResults ? "Show less" : "See more") {
                                withAnimation(.spring()) {
                                    showAllArtistResults.toggle()
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#FF00FF"))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                }

                // Users
                if !userResults.isEmpty {
                    Text("Users")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(userResults) { user in
                            UserRow(profile: user)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadDiscoverTracks() async {
        let artists = ["Daft Punk", "Tame Impala", "The Weeknd", "Arctic Monkeys", "Lorde"]
        
        await withTaskGroup(of: Track?.self) { group in
            for artist in artists {
                group.addTask {
                    let results = try? await MusicService.shared.search(query: artist)
                    return results?.first
                }
            }
            
            var tracks: [Track] = []
            for await track in group {
                if let track { tracks.append(track) }
            }
            
            await MainActor.run {
                discoverTracks = tracks
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                trackResults = []
                albumResults = []
                artistResults = []
                userResults = []
                isSearching = false
                showAllTrackResults = false
                showAllAlbumResults = false
                showAllArtistResults = false
            }
            return
        }

        await MainActor.run {
            isSearching = true
        }

        guard !Task.isCancelled else { return }

        do {
            async let tracks = try MusicService.shared.search(query: query)
            async let albums = try MusicService.shared.searchAlbums(query: query)
            async let artists = try MusicService.shared.searchArtists(query: query)
            async let users = try SupabaseManager.shared.searchUsers(query: query)
            var (trackRes, albumRes, artistRes, userRes) = try await (tracks, albums, artists, users)
            
            // Arama sorgusunu normalize et (küçük harf, boşlukları temizle)
            let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Albümleri sırala: Artist adı sorguyla eşleşenler önce
            albumRes.sort { album1, album2 in
                let artist1 = album1.artist.lowercased()
                let artist2 = album2.artist.lowercased()
                
                // Eğer birinin artist'i sorguyla eşleşiyorsa, o önce gelsin
                let match1 = artist1.contains(normalizedQuery) || normalizedQuery.contains(artist1)
                let match2 = artist2.contains(normalizedQuery) || normalizedQuery.contains(artist2)
                
                if match1 && !match2 {
                    return true // album1 önce
                } else if !match1 && match2 {
                    return false // album2 önce
                }
                // İkisi de eşleşiyorsa veya hiçbiri eşleşmiyorsa, iTunes'ın sıralamasını koru (zaten popülerliğe göre)
                return false
            }
            
            // Şarkıları da benzer şekilde sırala
            trackRes.sort { track1, track2 in
                let artist1 = track1.artist.lowercased()
                let artist2 = track2.artist.lowercased()
                
                let match1 = artist1.contains(normalizedQuery) || normalizedQuery.contains(artist1)
                let match2 = artist2.contains(normalizedQuery) || normalizedQuery.contains(artist2)
                
                if match1 && !match2 {
                    return true
                } else if !match1 && match2 {
                    return false
                }
                return false
            }
            
            await MainActor.run {
                // MusicKit results sorted by relevance.
                // We further prioritize artist name matches.
                self.trackResults = trackRes
                self.albumResults = albumRes
                self.artistResults = artistRes
                self.userResults = userRes
                self.isSearching = false
                self.showAllTrackResults = false
                self.showAllAlbumResults = false
                self.showAllArtistResults = false
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
            }
            print("Search error: \(error)")
        }
    }
}

// MARK: - Supporting Models

struct TrendingVibe: Identifiable {
    let id = UUID()
    let name: String
    let gradient: [Color]
    let icon: String
}

// MARK: - Discovery Content (extracted to prevent unnecessary recomputation)

struct DiscoveryContentView: View {
    let trendingVibes: [TrendingVibe]
    let discoverTracks: [Track]
    @Binding var searchText: String
    @Binding var selectedTrack: Track?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Trending Vibes Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Trending Vibes")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trendingVibes) { vibe in
                            TrendingVibeCard(vibe: vibe) {
                                searchText = vibe.name
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Quick Add Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Quick Add")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button("See All") {
                        // TODO: Navigate to full list
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#FF00FF"))
                }
                .padding(.horizontal)

                // Track list
                LazyVStack(spacing: 12) {
                    ForEach(discoverTracks) { track in
                        QuickAddTrackRow(track: track) {
                            selectedTrack = track
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Trending Vibe Card

struct TrendingVibeCard: View {
    let vibe: TrendingVibe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: vibe.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: vibe.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 80, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: vibe.gradient.first?.opacity(0.4) ?? .clear, radius: 10)
                
                Text(vibe.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(width: 90)
            .drawingGroup()
        }
    }
}

// MARK: - Quick Add Track Row

struct QuickAddTrackRow: View {
    let track: Track
    let onAddTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tappable area for track detail navigation
            NavigationLink(destination: TrackDetailView(track: track)) {
                HStack(spacing: 12) {
                    // Album Art
                    AsyncImage(url: URL(string: track.artworkUrl100)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Track Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Add Button (separate from navigation)
            Button(action: onAddTapped) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#FF00FF").opacity(0.4), radius: 6)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Album Row

struct AlbumRow: View {
    let album: Album
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album: album)) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: album.artworkUrl100)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(album.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    if let count = album.trackCount {
                        Text("\(count) tracks")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Artist Row

struct ArtistRow: View {
    let artist: Artist

    var body: some View {
        NavigationLink(destination: ArtistDetailView(artistName: artist.name, artistId: artist.id)) {
            HStack(spacing: 12) {
                // Artist artwork or initial
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF00FF").opacity(0.4), Color(hex: "#8B00FF").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    if let artworkUrl = artist.artworkUrl {
                        AsyncImage(url: artworkUrl) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Text(String(artist.name.prefix(1)).uppercased())
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                    } else {
                        Text(String(artist.name.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !artist.genres.isEmpty {
                        Text(artist.genres.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        Text("Artist")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - User Row

struct UserRow: View {
    let profile: Profile
    
    var body: some View {
        NavigationLink(destination: UserProfileView(userId: profile.id)) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                    } else {
                        Text(String((profile.username ?? "U").prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.username ?? "Anonymous")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - User Profile View (other users: follow/unfollow; self: edit)

struct UserProfileView: View {
    let userId: UUID
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var isCurrentUser = false
    @State private var isFollowing = false
    @State private var isFollowLoading = false
    @State private var totalLogs = 0
    @State private var averageRating: Double = 0
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var showEditProfile = false
    
    @State private var userReviews: [Review] = []
    @State private var userAlbumReviews: [AlbumReview] = []
    @State private var userTracks: [Int64: Track] = [:]
    @State private var userAlbums: [Int64: Album] = [:]
    @State private var selectedUserCategory: ProfileCategory = .songs
    
    private var sortedUserReviews: [Review] { userReviews.sorted { $0.rating > $1.rating } }
    private var sortedUserAlbumReviews: [AlbumReview] { userAlbumReviews.sorted { $0.rating > $1.rating } }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                ProgressView().tint(.white)
            } else if let currentProfile = profile {
                ScrollView {
                    VStack(spacing: 24) {
                        UserProfileHeader(
                            profile: currentProfile,
                            totalLogs: totalLogs,
                            averageRating: averageRating,
                            followersCount: followersCount,
                            followingCount: followingCount,
                            isCurrentUser: isCurrentUser,
                            isFollowing: isFollowing,
                            isFollowLoading: isFollowLoading,
                            onEditTapped: { showEditProfile = true },
                            onFollowTapped: { Task { await toggleFollow() } }
                        )
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 0) {
                                ProfileCategoryButton(
                                    title: "Songs",
                                    count: userReviews.count,
                                    isSelected: selectedUserCategory == .songs
                                ) {
                                    withAnimation(.spring()) { selectedUserCategory = .songs }
                                }
                                ProfileCategoryButton(
                                    title: "Albums",
                                    count: userAlbumReviews.count,
                                    isSelected: selectedUserCategory == .albums
                                ) {
                                    withAnimation(.spring()) { selectedUserCategory = .albums }
                                }
                                ProfileCategoryButton(
                                    title: "Artists",
                                    count: 0,
                                    isSelected: selectedUserCategory == .artists
                                ) {
                                    withAnimation(.spring()) { selectedUserCategory = .artists }
                                }
                            }
                            .padding(.horizontal)
                            
                            if selectedUserCategory == .songs {
                                if sortedUserReviews.isEmpty {
                                    Text("No songs logged yet")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                } else {
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                        ForEach(sortedUserReviews) { review in
                                            if let track = userTracks[review.itunesTrackId] {
                                                NavigationLink(destination: LogDetailView(track: track, review: review)) {
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
                            } else if selectedUserCategory == .albums {
                                if sortedUserAlbumReviews.isEmpty {
                                    Text("No albums rated yet")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                } else {
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                        ForEach(sortedUserAlbumReviews) { review in
                                            if let album = userAlbums[review.itunesCollectionId] {
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
                            } else {
                                Text("No artists rated yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .sheet(isPresented: $showEditProfile) {
                    if let profileToEdit = profile {
                        EditProfileView(
                            isPresented: $showEditProfile,
                            currentUsername: profileToEdit.username ?? "",
                            currentBio: profileToEdit.bio ?? "",
                            onSave: {
                                Task { await loadUserProfile() }
                            }
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
            }
        }
        .navigationTitle(profile?.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUserProfile()
        }
    }
    
    private func loadUserProfile() async {
        do {
            let currentUser = try await SupabaseManager.shared.getCurrentUser()
            let profileData = try await SupabaseManager.shared.getProfile(userId: userId)
            
            let isSelf = currentUser?.id == userId
            var following = false
            if !isSelf, let _ = currentUser {
                following = (try? await SupabaseManager.shared.isFollowing(userId: userId)) ?? false
            }
            
            let reviews = (try? await SupabaseManager.shared.getUserReviews(userId: userId)) ?? []
            let albumReviews = (try? await SupabaseManager.shared.getUserAlbumReviews(userId: userId)) ?? []
            let logsCount = reviews.count
            let avg: Double = reviews.isEmpty ? 0 : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count) / 2.0
            
            let followers = (try? await SupabaseManager.shared.getFollowers(userId: userId)) ?? []
            let followingList = (try? await SupabaseManager.shared.getFollowing(userId: userId)) ?? []
            
            await MainActor.run {
                self.profile = profileData
                self.isCurrentUser = isSelf
                self.isFollowing = following
                self.totalLogs = logsCount
                self.averageRating = avg
                self.followersCount = followers.count
                self.followingCount = followingList.count
                self.userReviews = reviews
                self.userAlbumReviews = albumReviews
                self.isLoading = false
            }
            
            var tracks: [Int64: Track] = [:]
            for id in Set(reviews.map { $0.itunesTrackId }) {
                if let track = try? await MusicService.shared.fetchTrack(id: id) {
                    tracks[id] = track
                }
            }
            await MainActor.run { self.userTracks = tracks }
            
            var albums: [Int64: Album] = [:]
            for id in Set(albumReviews.map { $0.itunesCollectionId }) {
                if let album = try? await MusicService.shared.fetchAlbum(collectionId: id) {
                    albums[id] = album
                }
            }
            await MainActor.run { self.userAlbums = albums }
        } catch {
            await MainActor.run { self.isLoading = false }
            print("Failed to load user profile: \(error)")
        }
    }
    
    private func toggleFollow() async {
        guard !isCurrentUser, !isFollowLoading else { return }
        await MainActor.run { isFollowLoading = true }
        
        do {
            if isFollowing {
                try await SupabaseManager.shared.unfollowUser(userId: userId)
                await MainActor.run {
                    isFollowing = false
                    followersCount = max(0, followersCount - 1)
                }
            } else {
                try await SupabaseManager.shared.followUser(userId: userId)
                await MainActor.run {
                    isFollowing = true
                    followersCount += 1
                }
            }
        } catch {
            print("Follow error: \(error)")
        }
        
        // Re-verify from server to be sure
        let serverFollowing = (try? await SupabaseManager.shared.isFollowing(userId: userId)) ?? isFollowing
        await MainActor.run {
            isFollowing = serverFollowing
            isFollowLoading = false
        }
    }
}

// MARK: - User Profile Header (with Follow / Edit)

struct UserProfileHeader: View {
    let profile: Profile
    let totalLogs: Int
    let averageRating: Double
    let followersCount: Int
    let followingCount: Int
    let isCurrentUser: Bool
    let isFollowing: Bool
    let isFollowLoading: Bool
    let onEditTapped: () -> Void
    let onFollowTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                
                if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    Text(String((profile.username ?? "U").prefix(1)).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text(profile.username ?? "Anonymous")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            HStack(spacing: 32) {
                UserProfileStatItem(value: "\(totalLogs)", label: "Logs")
                UserProfileStatItem(value: String(format: "%.1f", averageRating), label: "Avg")
                UserProfileStatItem(value: "\(followersCount)", label: "Followers")
                UserProfileStatItem(value: "\(followingCount)", label: "Following")
            }
            .padding(.top, 8)
            
            if isCurrentUser {
                Button(action: onEditTapped) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                }
            } else {
                Button(action: onFollowTapped) {
                    HStack(spacing: 6) {
                        if isFollowLoading {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                            Text(isFollowing ? "Following" : "Follow")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isFollowing ? .white.opacity(0.8) : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isFollowing {
                                Color.white.opacity(0.15)
                            } else {
                                LinearGradient(
                                    colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .clipShape(Capsule())
                }
                .disabled(isFollowLoading)
            }
        }
        .padding(.vertical, 20)
    }
}

struct UserProfileStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    SearchDiscoveryView()
}
