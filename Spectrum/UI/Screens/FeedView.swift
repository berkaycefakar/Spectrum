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
    
    var body: some View {
        NavigationStack {
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
                                Button("Try Again") {
                                    Task { await loadFeedData() }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                                        NavigationLink(destination: TrackDetailView(track: track)) {
                                            FeedCardView(
                                                track: track,
                                                vibeLabel: profile.username ?? "User",
                                                vibeColor: Color(hex: review.vibeColor),
                                                rating: Double(review.rating) / 2.0,
                                                reviewText: review.reviewText
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.white.opacity(0.05))
                                            .frame(height: 200)
                                            .overlay(ProgressView().tint(.white))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadFeedData()
            }
            .refreshable {
                await loadFeedData()
            }
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
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }
            
            // Try to fetch following reviews first (may fail if follows table doesn't exist)
            var feedReviews = (try? await SupabaseManager.shared.fetchFollowingReviews(userId: currentUser.id)) ?? []
            var showingRecent = false
            
            // Kimseyi takip etmiyorsa veya takip ettiklerinden review yoksa: tüm kullanıcıların son review'larını göster (bomboş kalmasın)
            if feedReviews.isEmpty {
                feedReviews = (try? await SupabaseManager.shared.fetchRecentReviews()) ?? []
                showingRecent = true
            }
            
            await MainActor.run {
                self.reviews = feedReviews
                self.isShowingRecentFallback = showingRecent
                self.isLoading = false
            }
            
            // Load track details and user profiles
            let trackIds = Set(feedReviews.map { $0.itunesTrackId })
            let userIds = Set(feedReviews.map { $0.userId })
            
            // Fetch all track details in one batched request instead of one-by-one.
            let fetchedTracks = await MusicService.shared.fetchTracks(ids: Array(trackIds))
            await MainActor.run {
                for (id, track) in fetchedTracks { self.tracks[id] = track }
            }
            
            // Fetch user profiles (batch)
            let userIdStrings = userIds.map { $0.uuidString }
            if let fetchedProfiles = try? await SupabaseManager.shared.batchGetProfiles(ids: userIdStrings) {
                await MainActor.run {
                    for profile in fetchedProfiles {
                        self.profiles[profile.id] = profile
                    }
                }
            }
            
        } catch {
            print("Failed to load feed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    FeedView()
}
