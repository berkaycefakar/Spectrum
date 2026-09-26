import SwiftUI
import Supabase

struct FeedView: View {
    // State for dynamic data
    @State private var reviews: [Review] = []
    @State private var tracks: [Int64: Track] = [:] // Cache for tracks
    @State private var profiles: [UUID: Profile] = [:] // Cache for user profiles
    @State private var isLoading = true
    @State private var errorMessage: String?
    /// True when feed is showing recent reviews (no one followed); false when showing following's reviews.
    @State private var isShowingRecentFallback = false
    /// Paging. The feed used to fetch a single fixed page — 50 rows from people you follow,
    /// or 20 from everyone — and simply stop. An active account hit that ceiling in a week
    /// and there was no way to see anything older.
    @State private var offset = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    /// Like count + "did I like it", keyed by review id. Loaded one page at a time alongside
    /// the artwork, never per card — thirty cards fetching their own would be thirty requests.
    @State private var likes: [UUID: LikeState] = [:]
    /// Needed to hide the heart on your own logs.
    @State private var currentUserId: UUID?
    @StateObject private var reselection = TabReselectionState.shared
    /// Value-based navigation so tapping Home while already on Home can pop back to the feed.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Ambient Glows (Static background glow, maybe dynamic later?)
                Circle()
                    .fill(Color(hex: "#A020F0").opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -100, y: -300)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Branded header: coloured prism mark + clean white wordmark.
                        HStack(spacing: 11) {
                            SpectrumMark(size: 32)
                            SpectrumWordmark(size: 30)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let error = errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.yellow)
                                Text("Oops!")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .multilineTextAlignment(.center)
                                Button {
                                    Task { await loadFeedData() }
                                } label: {
                                    // Inside the label so the whole pill is tappable, not
                                    // just the two words.
                                    Text("Try Again")
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .contentShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        } else if reviews.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("No activity yet")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("Log a song from Discover, or follow users to see their logs here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 50)
                        } else {
                            if isShowingRecentFallback {
                                Text("From everyone — follow users to personalize your feed")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                            LazyVStack(spacing: 20) {
                                ForEach(reviews) { review in
                                    if let track = tracks[review.itunesTrackId],
                                       let profile = profiles[review.userId] {
                                        NavigationLink(value: AppRoute.track(track)) {
                                            FeedCardView(
                                                track: track,
                                                vibeLabel: profile.username ?? "User",
                                                vibeColor: Color(hex: review.vibeColor),
                                                rating: Double(review.rating) / 2.0,
                                                // Masked on read: rows written before the
                                                // profanity filter existed are still in the DB.
                                                reviewText: review.reviewText.map(ProfanityFilter.masked),
                                                likeState: likes[review.id] ?? .unknown,
                                                // Nil on your own log: liking yourself isn't
                                                // a thing, and a disabled heart reads better
                                                // than one that silently does nothing.
                                                onToggleLike: review.userId == currentUserId
                                                    ? nil
                                                    : { toggleLike(review) }
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .moderationActions(
                                            contentType: .songReview,
                                            contentRef: review.id.uuidString,
                                            authorId: review.userId,
                                            authorUsername: profile.username,
                                            reportedText: review.reviewText,
                                            onBlocked: { Task { await loadFeedData() } }
                                        )
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.white.opacity(0.05))
                                            .frame(height: 200)
                                            .overlay(ProgressView().tint(.white))
                                    }
                                }

                                if hasMore {
                                    // Appears only once it scrolls into view, which is what
                                    // starts the next page — no button to hunt for.
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 24)
                                        .task(id: offset) { await loadNextPage() }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .tracksTabBarScroll(tab: 0)
            }
            .appRouteDestinations()
            .navigationBarHidden(true)
            .task {
                await loadFeedData()
            }
            .refreshable {
                await loadFeedData()
            }
        }
        .onChange(of: reselection.token(for: 0)) { _, _ in
            path = NavigationPath()
        }
    }
    
    // Fetch reviews from followed users (or recent reviews if not following anyone)
    private func loadFeedData() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            guard let currentUser = try await SupabaseManager.shared.getCurrentUser() else {
                await MainActor.run { self.isLoading = false }
                return
            }

            // Try the people you follow first (may fail if the follows table doesn't exist).
            var page = (try? await SupabaseManager.shared.fetchFollowingReviews(userId: currentUser.id))
                ?? .empty
            var showingRecent = false

            // Following nobody, or nobody you follow has logged anything: fall back to
            // everyone's recent logs so the first screen isn't empty.
            if page.reviews.isEmpty && !page.hasMore {
                page = (try? await SupabaseManager.shared.fetchRecentReviews()) ?? .empty
                showingRecent = true
            }

            await MainActor.run {
                self.currentUserId = currentUser.id
                self.reviews = page.reviews
                self.offset = SupabaseManager.pageSize
                self.hasMore = page.hasMore
                self.isShowingRecentFallback = showingRecent
                self.isLoading = false
            }

            await hydrate(page.reviews)
        } catch {
            debugLog("Failed to load feed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Appends the next page. Guarded against re-entry: the spinner's `.task` fires again
    /// whenever the view is recreated, and two overlapping fetches would append the same
    /// rows twice.
    private func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        await MainActor.run { self.isLoadingMore = true }
        defer { Task { @MainActor in self.isLoadingMore = false } }

        guard let currentUser = try? await SupabaseManager.shared.getCurrentUser() else { return }

        let currentOffset = offset
        let page: SupabaseManager.ReviewPage
        if isShowingRecentFallback {
            page = (try? await SupabaseManager.shared.fetchRecentReviews(offset: currentOffset)) ?? .empty
        } else {
            page = (try? await SupabaseManager.shared.fetchFollowingReviews(
                userId: currentUser.id,
                offset: currentOffset
            )) ?? .empty
        }

        await MainActor.run {
            // A blocked-user page comes back empty but is not the end of the feed, so the
            // offset advances on every page regardless of how many rows survived the filter.
            let known = Set(self.reviews.map(\.id))
            self.reviews.append(contentsOf: page.reviews.filter { !known.contains($0.id) })
            self.offset = currentOffset + SupabaseManager.pageSize
            self.hasMore = page.hasMore
        }

        await hydrate(page.reviews)
    }

    /// Resolves the artwork and author for a page of reviews. Both caches are additive, so
    /// appending a page never re-fetches what earlier pages already hold.
    private func hydrate(_ page: [Review]) async {
        guard !page.isEmpty else { return }

        let knownTracks = await MainActor.run { Set(self.tracks.keys) }
        let knownProfiles = await MainActor.run { Set(self.profiles.keys) }

        let trackIds = Set(page.map(\.itunesTrackId)).subtracting(knownTracks)
        let userIds = Set(page.map(\.userId)).subtracting(knownProfiles)

        if !trackIds.isEmpty {
            let fetched = await MusicService.shared.fetchTracks(ids: Array(trackIds))
            await MainActor.run {
                for (id, track) in fetched { self.tracks[id] = track }
            }
        }

        if !userIds.isEmpty,
           let fetched = try? await SupabaseManager.shared.batchGetProfiles(ids: userIds.map(\.uuidString)) {
            await MainActor.run {
                for profile in fetched { self.profiles[profile.id] = profile }
            }
        }

        let states = await SupabaseManager.shared.likeStates(
            contentType: .songReview,
            contentIds: page.map(\.id)
        )
        await MainActor.run {
            // Merge rather than replace: an optimistic toggle the user made while this page
            // was in flight must not be overwritten by the older server value.
            for (id, state) in states where self.likes[id] == nil {
                self.likes[id] = state
            }
        }
    }

    /// Optimistic like: the heart flips in the same frame as the tap, and only reverts if
    /// the write actually fails. Waiting for the round-trip made every tap feel broken on a
    /// slow connection.
    private func toggleLike(_ review: Review) {
        let previous = likes[review.id] ?? .unknown
        let next = previous.toggled()
        likes[review.id] = next

        Task {
            do {
                if next.likedByMe {
                    try await SupabaseManager.shared.like(contentType: .songReview, contentId: review.id)
                } else {
                    try await SupabaseManager.shared.unlike(contentType: .songReview, contentId: review.id)
                }
            } catch {
                debugLog("Like toggle failed: \(error)")
                await MainActor.run { self.likes[review.id] = previous }
            }
        }
    }
}

#Preview {
    FeedView()
}
