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
    @State private var artworkColor: ArtworkColor = .placeholder

    /// Derived from the artist photo rather than fixed, so a black-and-white press shot no
    /// longer gets a magenta wash.
    private var accentColor: Color { artworkColor.accent }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    heroSection

                    if isLoadingArtist {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 20)
                    } else {
                        if let artist = artist {
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
                        }
                    }

                    ratingSection
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadArtistData()
            await loadUserArtistReview()
        }
        .task(id: artist?.artworkUrl) {
            await loadArtworkColor()
        }
    }

    // MARK: - Hero Section

    /// Full-bleed square artist photo filling the top of the screen, with the name laid over
    /// a scrim that fades into the page background.
    private var heroSection: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // Slightly taller than square so the name has room to sit inside the image
            // rather than crowding it.
            let height = width * 1.1

            ZStack(alignment: .bottomLeading) {
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
        }
        // GeometryReader has no intrinsic height, so the aspect ratio has to be restated
        // here or the hero collapses inside the ScrollView.
        .aspectRatio(1 / 1.1, contentMode: .fit)
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
                if newValue > 0 {
                    saveArtistRating()
                }
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

    private func loadUserArtistReview() async {
        guard let user = try? await SupabaseManager.shared.getCurrentUser() else { return }

        do {
            let reviews = try await SupabaseManager.shared.getUserArtistReviews(userId: user.id)
            if let review = reviews.first(where: { $0.artistName == artistName }) {
                await MainActor.run {
                    userArtistReview = review
                    artistRating = Double(review.rating) / 2.0
                }
            }
        } catch {
            print("Failed to load artist review: \(error)")
        }
    }

    private func saveArtistRating() {
        guard !isSaving, artistRating > 0 else { return }
        isSaving = true

        Task {
            do {
                let storedRating = Int((artistRating * 2).rounded())
                try await SupabaseManager.shared.saveArtistReview(
                    artistName: artistName,
                    rating: storedRating,
                    text: "",
                    vibeColor: accentColor.hexString
                )
                await loadUserArtistReview()
                await MainActor.run { isSaving = false }
            } catch {
                await MainActor.run { isSaving = false }
                print("Failed to save artist rating: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(artistName: "Daft Punk")
    }
}
