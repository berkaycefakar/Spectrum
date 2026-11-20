import SwiftUI
// `User.id` lives in the Auth module, which `Supabase` re-exports.
import Supabase

struct TrackDetailView: View {
    let track: Track

    @ObservedObject private var audioManager = AudioManager.shared
    @State private var showAddLog = false
    /// Set from a review card's author; pushes that user's profile.
    @State private var profileToOpen: UUID?
    @State private var showAddToList = false
    @State private var showArtwork = false
    @State private var showSend = false
    @State private var artworkColor: ArtworkColor = .placeholder

    private var dominantColor: Color { artworkColor.accent }

    /// The Log button is filled with the artwork accent, which can be anything from a dark
    /// navy to a pale cream — so its label has to follow the fill, not a fixed white.
    private var logTextColor: Color { dominantColor.contrastingForeground }

    private var isPlaying: Bool {
        audioManager.isTrackPlaying(track.id)
    }
    
    /// Whose log is whose — the owner gets edit and delete on the detail screen, everyone
    /// else gets it read-only.
    @ObservedObject private var sessionStore = SessionStore.shared
    private var currentUserId: UUID? { sessionStore.currentUser?.id }

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
            // The page takes the cover's colour, the way Apple Music tints an album page.
            pageBackground

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    
                    VStack(spacing: 24) {
                        actionBar

                        previewPlayer

                        if let album = album {
                            albumLink(album: album)
                        }

                        CommunityStatsCard(
                            stats: communityStats,
                            countLabel: String(localized: "logs", bundle: appStringsBundle),
                            countLabelSingular: String(localized: "log", bundle: appStringsBundle),
                            emptyMessage: String(localized: "No logs yet — be the first!", bundle: appStringsBundle)
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
        .fullScreenCover(isPresented: $showArtwork) { ArtworkViewer(url: track.artworkUrl600) }
        .sheet(isPresented: $showSend) {
            SendToFriendView(kind: .song, contentRef: String(track.id), title: track.title,
                             subtitle: track.artist, artworkURL: track.artworkUrl600)
        }
        .navigationDestination(item: $profileToOpen) { UserProfileView(userId: $0) }
        .sheet(isPresented: $showAddToList) {
            AddToListView(kind: .song, contentRef: String(track.id), displayTitle: track.title)
        }
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
        // Deliberately does *not* stop playback on disappear any more. Killing the preview
        // when this screen went away was the right call while this was the only place with a
        // pause button; now the mini-player follows the sound across every tab, and stopping
        // here would make backing out of the page the one action that silences it.
    }
    
    /// Black, washed with the cover's colour: strongest at the top, deepening further down.
    private var pageBackground: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [dominantColor.opacity(0.55), dominantColor.opacity(0.32), dominantColor.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: dominantColor)
    }

    // MARK: - Hero Section

    /// Apple Music-style hero: the cover almost full width over a blurred copy of itself.
    ///
    /// Sized from the container width, not from what the ScrollView has spare, so logs
    /// loading in below never squeeze it or slide the artwork upward.
    private var heroSection: some View {
        VStack(spacing: 22) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                AsyncImage(url: track.artworkUrl600) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }
                }
                .containerRelativeFrame(.horizontal) { width, _ in width - 56 }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                .onTapGesture { showArtwork = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("Show cover full screen", bundle: appStringsBundle))

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

                    CatalogBadgeRow(
                        isExplicit: track.isExplicit,
                        tint: artworkColor.isNeutral ? .white : dominantColor
                    )

                    // Composer. Music's answer to Letterboxd's director credit, and the one
                    // line that makes a classical or a jazz log mean something. Hidden when
                    // it merely repeats the performer, which is how pop records are filed.
                    if let composer = track.composerName,
                       !composer.isEmpty,
                       composer.caseInsensitiveCompare(track.artist) != .orderedSame {
                        Text("Written by \(composer)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                    }
                }
        }
        .padding(.top, 110)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Blurred copy of the cover behind the hero, fading into the page.
            AsyncImage(url: track.artworkUrl600) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .blur(radius: 60)
            .overlay(Color.black.opacity(0.35))
            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
            .clipped()
        }
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

            // Playback used to be one more 48pt circle in this row, indistinguishable from
            // Share and Add to List — the main thing you come to a song's page to do, drawn
            // at the size of a secondary action. It has its own card below now.

            // Share — circle button.
            //
            // `ShareLink` rather than presenting a UIActivityViewController by hand: the old
            // code reached for `connectedScenes.first`, which is not necessarily the active
            // scene, and presented on the root controller — so the sheet silently failed to
            // appear whenever this screen was itself inside a presented sheet.
            // Add to list — circle button
            Button {
                showAddToList = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add to List")

            // Share opens a menu: listen on Apple Music, Spotify or YouTube Music, or send
            // a song.link URL so the person receiving it can choose their own service.
            ListenOnMenu(track: track, onSendToFriend: { showSend = true }) {
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

    // MARK: - Preview Player

    /// The preview, given the room it deserves.
    ///
    /// A 30-second clip with no sense of where you are in it is a worse experience than it
    /// needs to be — this draws a scrubbable progress bar, an elapsed/remaining readout and a
    /// 64pt play button, so the page has an obvious centre of gravity.
    private var previewPlayer: some View {
        let hasPreview = track.previewUrl != nil
        let isLoaded = audioManager.isTrackLoaded(track.id)
        let isBuffering = audioManager.isTrackBuffering(track.id)
        // Only trust the manager's clock while *this* track is the one loaded in it. Another
        // song's progress would otherwise bleed into this page's bar.
        let progress = isLoaded ? audioManager.progress : 0
        let elapsed = isLoaded ? audioManager.currentTime : 0
        let total = isLoaded && audioManager.duration > 0 ? audioManager.duration : previewLength

        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                Button {
                    toggleAudio()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [dominantColor, dominantColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        if isBuffering {
                            ProgressView()
                                .tint(logTextColor)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(logTextColor)
                                // `play.fill` is visually left-heavy; nudging it back centres
                                // it in the circle the way the pause bars already are.
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .shadow(color: dominantColor.opacity(0.45), radius: 14, y: 4)
                    .animation(.easeInOut(duration: 0.45), value: dominantColor)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!hasPreview)
                .opacity(hasPreview ? 1 : 0.35)
                .accessibilityLabel(isPlaying ? String(localized: "Pause preview", bundle: appStringsBundle) : String(localized: "Play preview", bundle: appStringsBundle))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(hasPreview ? String(localized: "PREVIEW", bundle: appStringsBundle) : String(localized: "NO PREVIEW", bundle: appStringsBundle))
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer(minLength: 8)
                        AppleMusicBadge(url: track.appleMusicLink, height: 24)
                    }

                    if hasPreview {
                        PreviewScrubBar(
                            progress: progress,
                            accent: dominantColor,
                            isEnabled: isLoaded,
                            onScrub: { audioManager.seek(toFraction: $0) }
                        )

                        HStack {
                            Text(Self.timecode(elapsed))
                            Spacer()
                            Text("-" + Self.timecode(max(total - elapsed, 0)))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))

                        ApplePreviewCredit()
                    } else {
                        Text("Apple Music doesn't offer a clip for this track.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [dominantColor.opacity(0.35), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    /// What the bar shows before the asset's real length is known. Apple's catalog previews
    /// are 30 seconds; this is only the placeholder, the player uses the measured value.
    private let previewLength: Double = 30

    private static func timecode(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    // MARK: - Album Link

    /// The album as a plain row between hairlines, like a credit rather than a card.
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
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(albumSubtitle(album))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "Album · 2015"
    private func albumSubtitle(_ album: Album) -> String {
        let kind = String(localized: "Album", bundle: appStringsBundle)
        guard let date = album.releaseDate else { return kind }
        return "\(kind) · \(date.formatted(.dateTime.year()))"
    }

    // MARK: - Reviews Section
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only carries the written reviews now — the numbers moved into CommunityStatsCard.
            if !trackReviews.isEmpty || isLoadingReviews {
                Text("Reviews")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            if isLoadingReviews {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if trackReviews.isEmpty {
                EmptyView()
            } else {
                // Side by side, like reviews on the App Store: each one a card to swipe past.
                ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(trackReviews) { review in
                        // The card used to be inert: you could read someone's review of the
                        // song and had no way to open it, which made every other log in the
                        // app a dead end from here.
                        NavigationLink(
                            destination: LogDetailView(
                                track: track,
                                review: review,
                                isOwner: review.userId == currentUserId,
                                authorUsername: reviewProfiles[review.userId]?.username,
                                onChanged: { Task { await loadTrackReviews() } },
                                showsSongLink: false
                            )
                        ) {
                            TrackReviewCard(
                                review: review,
                                profile: reviewProfiles[review.userId],
                                onTapAuthor: { profileToOpen = review.userId }
                            )
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal) { width, _ in
                            trackReviews.count == 1 ? width : width * 0.82
                        }
                    }
                }
                .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
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
        #if DEBUG
        if DemoMode.isOn {
            trackReviews = (DemoData.feed + DemoData.myReviews).filter { $0.itunesTrackId == Int64(track.id) }
            reviewProfiles = DemoData.profilesById
            isLoadingReviews = false
            return
        }
        #endif
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
            debugLog("Failed to load track reviews: \(error)")
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
        audioManager.toggle(track: track)
    }
    
}

// MARK: - Scrub Bar

/// A draggable progress bar for the preview.
///
/// Deliberately not a `Slider`: a Slider only moves from its knob, and on a 3pt-tall track
/// that is a 30-second clip's worth of precision in a target you can't hit. This takes a drag
/// anywhere along the bar and reports the fraction.
private struct PreviewScrubBar: View {
    let progress: Double
    let accent: Color
    /// False before the track has ever been played, when there is nothing to seek within.
    let isEnabled: Bool
    let onScrub: (Double) -> Void

    /// Local override while a drag is in flight, so the bar follows the finger rather than the
    /// player's clock.
    @State private var dragProgress: Double?

    private var shown: Double { dragProgress ?? progress }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.14))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * shown, 0))

                Circle()
                    .fill(.white)
                    .frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.35), radius: 3)
                    .offset(x: max(width * shown - 5.5, -5.5))
                    .opacity(isEnabled ? 1 : 0)
            }
            .frame(height: 5)
            .frame(maxHeight: .infinity)
            // A 5pt bar is far below the 44pt minimum, so the gesture takes the whole row's
            // height instead of the bar's.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled, width > 0 else { return }
                        dragProgress = min(max(value.location.x / width, 0), 1)
                    }
                    .onEnded { value in
                        guard isEnabled, width > 0 else { return }
                        let fraction = min(max(value.location.x / width, 0), 1)
                        onScrub(fraction)
                        dragProgress = nil
                    }
            )
        }
        .frame(height: 18)
        .animation(.linear(duration: 0.2), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Preview position")
        .accessibilityValue("\(Int(shown * 100)) percent")
    }
}

// MARK: - Track Review Card

struct TrackReviewCard: View {
    let review: Review
    let profile: Profile?
    /// Opens the author's profile from the avatar and name.
    var onTapAuthor: (() -> Void)? = nil

    private var name: String { profile?.username ?? String(localized: "Anonymous", bundle: appStringsBundle) }
    private var stars: Double { Double(review.rating) / 2.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { onTapAuthor?() } label: {
                    HStack(spacing: 10) {
                        avatar
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(review.createdAt.timeAgoDisplay())
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens their profile")

                Spacer(minLength: 4)

                Circle()
                    .fill(Color(hex: review.vibeColor))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }

            starRow

            if let text = review.reviewText, !text.isEmpty {
                // Masked on read: rows written before the profanity filter are still in the DB.
                Text(ProfanityFilter.masked(text))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
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

    /// Five small stars, filled to the score (halves included).
    private var starRow: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                let d = Double(i)
                Image(systemName: stars >= d ? "star.fill" : (stars >= d - 0.5 ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(Color(hex: "#FFCC00"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(String(format: "%.1f", stars)) stars"))
    }

    private var avatar: some View {
        let initial = Circle()
            .fill(Color(hex: review.vibeColor).opacity(0.35))
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            )
        return Group {
            if let url = profile?.avatarUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { initial }
                }
            } else {
                initial
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
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
