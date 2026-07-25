import SwiftUI
import Supabase

/// Artist detail screen: artwork, genres, bio, top songs, albums, and user rating.
struct ArtistDetailView: View {
    let artistName: String
    /// Optional MusicKit artist ID for fetching detailed data.
    var artistId: String? = nil

    @State private var artist: Artist?
    @State private var isLoadingArtist = true
    @State private var artistRating: Double = 0
    @State private var isSaving = false
    @State private var userArtistReview: ArtistReview?
    @State private var communityReviews: [ArtistReview] = []
    @State private var artworkColor: ArtworkColor = .placeholder
    /// The value currently stored on the server. Loading an existing rating pushes it into
    /// `artistRating`, which fires `onChange` — without this we'd immediately write back the
    /// exact value we just read, on every visit to the page.
    @State private var persistedRating: Double?
    /// In-flight debounce. Dragging the control emits a change per step; each one used to
    /// start its own save, and the `isSaving` guard silently dropped the later ones — so the
    /// rating that landed in the database was the first step of the drag, not the last.
    @State private var ratingSaveTask: Task<Void, Never>?

    private var communityStats: CommunityStats {
        CommunityStats(
            ratings: communityReviews.map(\.rating),
            vibeHexes: communityReviews.map(\.vibeColor)
        )
    }

    /// Derived from the artist photo rather than fixed, so a black-and-white press shot no
    /// longer gets a magenta wash.
    private var accentColor: Color { artworkColor.accent }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // The hero is sized from the container width rather than from whatever height the
            // ScrollView has spare — otherwise every section that loads in below it (top songs,
            // albums, community) steals height and drags the photo upward.
            GeometryReader { container in
                ScrollView {
                    VStack(spacing: 28) {
                        heroSection(width: container.size.width)

                        communitySection

                        if isLoadingArtist {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 20)
                        } else if let artist = artist {
                            if !artist.genres.isEmpty {
                                genresSection(genres: artist.genres)
                            }

                            if let notes = artist.editorialNotes, !notes.isEmpty {
                                bioSection(notes: notes)
                            }

                            if !artist.topSongs.isEmpty {
                                topSongsSection(songs: artist.topSongs)
                            }

                            if !artist.albums.isEmpty {
                                albumsSection(albums: artist.albums)
                            }

                            if !artist.similarArtists.isEmpty {
                                similarArtistsSection(artists: artist.similarArtists)
                            }
                        }

                        ratingSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // The three loads are independent — the artist's catalogue comes from MusicKit,
            // the ratings from Supabase. Running them sequentially made the page's slowest
            // request the sum of all three.
            async let details: Void = loadArtistData()
            async let ownRating: Void = loadUserArtistReview()
            async let community: Void = loadCommunityReviews()
            _ = await (details, ownRating, community)
        }
        .task(id: artist?.artworkUrl) {
            await loadArtworkColor()
        }
    }

    // MARK: - Hero Section

    /// Full-bleed square artist photo filling the top of the screen, with the name laid over
    /// a scrim that fades into the page background.
    private func heroSection(width: CGFloat) -> some View {
        // Slightly taller than square so the name has room to sit inside the image
        // rather than crowding it.
        let height = width * 1.1

        return ZStack(alignment: .bottomLeading) {
            if let artworkUrl = artist?.artworkUrl {
                AsyncImage(url: artworkUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        artistInitialView
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            } else {
                artistInitialView
                    .frame(width: width, height: height)
            }

            // Scrim: keeps the name legible over bright photos and blends the image
            // into the black page below.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.15), location: 0.45),
                    .init(color: .black.opacity(0.75), location: 0.78),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)

            VStack(alignment: .leading, spacing: 8) {
                Text("ARTIST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.65))

                Text(artistName)
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Community

    private var communitySection: some View {
        CommunityStatsCard(
            stats: communityStats,
            emptyMessage: "No one has rated \(artistName) yet"
        )
        .padding(.horizontal, 24)
    }

    private var artistInitialView: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.45), .black],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(String(artistName.prefix(1)).uppercased())
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Genres

    private func genresSection(genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bio / Editorial Notes

    private func bioSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.5))

            // Strip HTML tags from editorial notes
            Text(notes.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Top Songs

    private func topSongsSection(songs: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Songs")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            LazyVStack(spacing: 0) {
                ForEach(Array(songs.prefix(5).enumerated()), id: \.element.id) { index, track in
                    NavigationLink(destination: TrackDetailView(track: track)) {
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Text("\(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.35))
                                    .frame(width: 24)

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

                            if index < min(songs.count, 5) - 1 {
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
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Albums

    private func albumsSection(albums: [Album]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albums")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            VStack(spacing: 8) {
                                AsyncImage(url: album.artworkUrl600) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.white.opacity(0.1)
                                            .overlay(
                                                Image(systemName: "opticaldisc")
                                                    .foregroundStyle(.white.opacity(0.3))
                                            )
                                    }
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: accentColor.opacity(0.2), radius: 8)

                                VStack(spacing: 2) {
                                    Text(album.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    if let releaseDate = album.releaseDate {
                                        Text(releaseDate, format: .dateTime.year())
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                            }
                            .frame(width: 130)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Similar Artists

    /// "Fans also like". Mirrors the albums row's rhythm and spacing, but circular — a square
    /// tile reads as a record sleeve, and these are people.
    private func similarArtistsSection(artists: [ArtistBrief]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Similar Artists")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { similar in
                        NavigationLink(
                            destination: ArtistDetailView(artistName: similar.name, artistId: similar.id)
                        ) {
                            VStack(spacing: 8) {
                                similarArtistPhoto(for: similar)

                                Text(similar.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 32, alignment: .top)
                            }
                            .frame(width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func similarArtistPhoto(for similar: ArtistBrief) -> some View {
        ZStack {
            if let url = similar.artworkUrl {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        similarArtistInitial(for: similar.name)
                    }
                }
            } else {
                similarArtistInitial(for: similar.name)
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: accentColor.opacity(0.2), radius: 8)
    }

    private func similarArtistInitial(for name: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.35), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your rating")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                RatingLabel(rating: artistRating, maxRating: 5, accentColor: accentColor)
            }

            SpectrumRatingControl(
                rating: $artistRating,
                accentColor: accentColor
            )
            .onChange(of: artistRating) { _, newValue in
                scheduleRatingSave(newValue)
            }

            if isSaving {
                HStack(spacing: 8) {
                    ProgressView().tint(.white.opacity(0.6))
                    Text("Saving...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if userArtistReview != nil {
                Text("Rating saved")
                    .font(.footnote)
                    .foregroundStyle(accentColor.opacity(0.9))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Data Loading

    private func loadArtistData() async {
        // Try to fetch by ID first, then by name search
        if let id = artistId {
            if let fetched = try? await MusicService.shared.fetchArtist(id: id) {
                await MainActor.run {
                    self.artist = fetched
                    self.isLoadingArtist = false
                }
                return
            }
        }

        // Fallback: search by name
        if let results = try? await MusicService.shared.searchArtists(query: artistName),
           let match = results.first {
            // Fetch detailed artist data with top songs and albums
            if let detailed = try? await MusicService.shared.fetchArtist(id: match.id) {
                await MainActor.run {
                    self.artist = detailed
                    self.isLoadingArtist = false
                }
                return
            }
            await MainActor.run {
                self.artist = match
                self.isLoadingArtist = false
            }
            return
        }

        await MainActor.run { self.isLoadingArtist = false }
    }

    private func loadArtworkColor() async {
        guard let url = artist?.artworkUrl else { return }
        let color = await ArtworkColorLoader.shared.color(for: url)
        withAnimation(.easeInOut(duration: 0.45)) {
            artworkColor = color
        }
    }

    private func loadCommunityReviews() async {
        guard let list = try? await SupabaseManager.shared.getArtistReviews(artistName: artistName) else { return }
        await MainActor.run { self.communityReviews = list }
    }

    private func loadUserArtistReview() async {
        do {
            guard let review = try await SupabaseManager.shared.getUserArtistReview(artistName: artistName) else { return }
            await MainActor.run {
                userArtistReview = review
                artistRating = Double(review.rating) / 2.0
                persistedRating = artistRating
            }
        } catch {
            print("Failed to load artist review: \(error)")
        }
    }

    /// Coalesces a drag into a single write, ~half a second after the user settles.
    private func scheduleRatingSave(_ rating: Double) {
        ratingSaveTask?.cancel()

        // Nothing to store yet, or this is the value we just read back from the server.
        guard rating > 0, rating != persistedRating else { return }

        ratingSaveTask = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            await saveArtistRating(rating)
        }
    }

    private func saveArtistRating(_ rating: Double) async {
        await MainActor.run { isSaving = true }

        do {
            let storedRating = Int((rating * 2).rounded())
            try await SupabaseManager.shared.saveArtistReview(
                artistName: artistName,
                rating: storedRating,
                text: "",
                vibeColor: accentColor.hexString
            )
            await MainActor.run { persistedRating = rating }
            await loadUserArtistReview()
            await loadCommunityReviews()
        } catch {
            print("Failed to save artist rating: \(error)")
        }

        await MainActor.run { isSaving = false }
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(artistName: "Daft Punk")
    }
}
