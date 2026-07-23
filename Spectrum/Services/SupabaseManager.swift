import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Configuration Placeholders
    private let supabaseURL = URL(string: "https://ysgbqlltzdhgsezukxxm.supabase.co")!
    // FIX: Ensure the key is on a single line without breaks
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzZ2JxbGx0emRoZ3NlenVreHhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwMDU2NTYsImV4cCI6MjA4NDU4MTY1Nn0.C6cpEojPrZw4DEHNTePMEhrn0cikqfZ9oUvCEN63LLQ"
    
    /// Deep link used by Supabase email confirmations / magic links.
    /// You must also add this to Supabase Dashboard → Auth → URL Configuration → Redirect URLs.
    private let authRedirectURL = URL(string: "spectrum://auth-callback")!
    
    let client: SupabaseClient
    
    private init() {
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                redirectToURL: authRedirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey, options: options)
    }
    
    // MARK: - Auth
    
    /// Returns the currently authenticated user, or nil if not logged in.
    /// In Supabase Swift 2.x, session is accessed via currentSession (sync) or session (async).
    func getCurrentUser() async throws -> User? {
        // Use currentSession for synchronous access - returns nil if not logged in
        return client.auth.currentSession?.user
    }
    
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String, username: String) async throws {
        // 1. Create Auth User
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username)],
            redirectTo: authRedirectURL
        )
        
        // 2. Manually create Profile row to avoid Trigger issues
        // In current Supabase Swift, `response.user` is non-optional, so we access `id` directly.
        let userId = response.user.id
        let profile = Profile(id: userId, username: username, avatarUrl: nil, bio: nil)
        try await client.from("profiles").insert(profile).execute()
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Profiles
    
    func getProfile(userId: UUID) async throws -> Profile {
        let response: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return response
    }
    
    func updateProfile(userId: UUID, username: String, bio: String) async throws {
        let updateData = ProfileUpdate(username: username, bio: bio)
        try await client
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    /// Updates username, bio, and (optionally) the avatar URL in one call.
    func updateProfile(userId: UUID, username: String, bio: String, avatarUrl: String?) async throws {
        let updateData = ProfileUpdateFull(username: username, bio: bio, avatar_url: avatarUrl)
        try await client
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    /// Uploads avatar image data to the `avatars` storage bucket and returns its public URL.
    /// Requires a public bucket named `avatars` to exist in Supabase Storage.
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        // Per-user folder so a storage policy can restrict writes to a user's own folder.
        // Stable filename so a new upload overwrites the old avatar instead of piling up.
        let path = "\(userId.uuidString)/avatar.jpg"

        try await client.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )

        // Cache-buster: the public URL is stable across uploads, so without this the UI would
        // keep showing the previous image from cache.
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        return publicURL.absoluteString + "?v=\(Int(Date().timeIntervalSince1970))"
    }
    
    // MARK: - Reviews
    
    func getUserReviews(userId: UUID) async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    func saveReview(trackId: Int, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let newReview = NewReview(
            user_id: user.id,
            itunes_track_id: Int64(trackId),
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )

        // Upsert so re-logging a song updates the existing entry instead of creating a
        // duplicate. Requires a unique (user_id, itunes_track_id) constraint on `reviews`.
        try await client
            .from("reviews")
            .upsert(newReview, onConflict: "user_id,itunes_track_id")
            .execute()
    }

    /// Deletes the current user's log for a track.
    func deleteReview(trackId: Int64) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        try await client
            .from("reviews")
            .delete()
            .eq("user_id", value: user.id)
            .eq("itunes_track_id", value: Int(trackId))
            .execute()
    }
    
    /// Track ids that the community has logged most recently, de-duplicated, newest first.
    /// Used to drive a real "trending" row on Discover instead of a hardcoded artist list.
    func fetchTrendingTrackIds(limit: Int = 20) async throws -> [Int64] {
        struct Row: Decodable { let itunes_track_id: Int64 }
        let rows: [Row] = try await client
            .from("reviews")
            .select("itunes_track_id")
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value

        // Preserve recency order while removing repeats.
        var seen = Set<Int64>()
        var ordered: [Int64] = []
        for row in rows where !seen.contains(row.itunes_track_id) {
            seen.insert(row.itunes_track_id)
            ordered.append(row.itunes_track_id)
            if ordered.count >= limit { break }
        }
        return ordered
    }

    func getTrackReviews(trackId: Int64) async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .eq("itunes_track_id", value: Int(trackId))
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    // MARK: - Album Reviews
    
    func saveAlbumReview(collectionId: Int64, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let newReview = NewAlbumReview(
            user_id: user.id,
            itunes_collection_id: collectionId,
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )
        
        // Upsert so the user can update rating/review for same album
        try await client
            .from("album_reviews")
            .upsert(newReview)
            .execute()
    }
    
    func getUserAlbumReviews(userId: UUID) async throws -> [AlbumReview] {
        let response: [AlbumReview] = try await client
            .from("album_reviews")
            .select()
            .eq("user_id", value: userId)
            .order("rating", ascending: false) // Highest first
            .execute()
            .value
        return response
    }
    
    func getAlbumReviews(collectionId: Int64) async throws -> [AlbumReview] {
        let response: [AlbumReview] = try await client
            .from("album_reviews")
            .select()
            .eq("itunes_collection_id", value: Int(collectionId))
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    // MARK: - Artist Reviews
    
    func saveArtistReview(artistName: String, rating: Int, text: String, vibeColor: String) async throws {
        guard let user = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let newReview = NewArtistReview(
            user_id: user.id,
            artist_name: artistName,
            rating: rating,
            review_text: text,
            vibe_color: vibeColor
        )
        
        // Upsert, not insert: (user_id, artist_name) is unique, so re-rating an artist you
        // already logged would otherwise fail on the duplicate key.
        try await client
            .from("artist_reviews")
            .upsert(newReview, onConflict: "user_id,artist_name")
            .execute()
    }
    
    func getUserArtistReviews(userId: UUID) async throws -> [ArtistReview] {
        let response: [ArtistReview] = try await client
            .from("artist_reviews")
            .select()
            .eq("user_id", value: userId)
            .order("rating", ascending: false) // Highest first
            .execute()
            .value
        return response
    }
    
    func getArtistReviews(artistName: String) async throws -> [ArtistReview] {
        let response: [ArtistReview] = try await client
            .from("artist_reviews")
            .select()
            .eq("artist_name", value: artistName)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }
    
    // MARK: - User Search
    
    func searchUsers(query: String) async throws -> [Profile] {
        let response: [Profile] = try await client
            .from("profiles")
            .select()
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
        return response
    }
    
    // MARK: - Follows
    
    func followUser(userId: UUID) async throws {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Check first to avoid duplicate insert
        let already = try await isFollowing(userId: userId)
        if already { return }
        
        struct FollowInsert: Encodable {
            let follower_id: UUID
            let following_id: UUID
        }
        
        let follow = FollowInsert(follower_id: currentUser.id, following_id: userId)
        
        try await client
            .from("follows")
            .insert(follow)
            .execute()
    }
    
    func unfollowUser(userId: UUID) async throws {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        try await client
            .from("follows")
            .delete()
            .eq("follower_id", value: currentUser.id)
            .eq("following_id", value: userId)
            .execute()
    }
    
    func getFollowing(userId: UUID) async throws -> [Profile] {
        struct FollowRow: Codable {
            let following_id: UUID
        }

        let response: [FollowRow] = try await client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value

        guard !response.isEmpty else { return [] }
        let ids = response.map { $0.following_id.uuidString }
        return try await batchGetProfiles(ids: ids)
    }

    func getFollowers(userId: UUID) async throws -> [Profile] {
        struct FollowRow: Codable {
            let follower_id: UUID
        }

        let response: [FollowRow] = try await client
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: userId)
            .execute()
            .value

        guard !response.isEmpty else { return [] }
        let ids = response.map { $0.follower_id.uuidString }
        return try await batchGetProfiles(ids: ids)
    }

    /// Batch fetch profiles by IDs in a single query (avoids N+1)
    func batchGetProfiles(ids: [String]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        let response: [Profile] = try await client
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        return response
    }
    
    func isFollowing(userId: UUID) async throws -> Bool {
        guard let currentUser = try await getCurrentUser() else {
            return false
        }
        
        struct FollowCheck: Codable {
            let follower_id: UUID
        }
        
        let response: [FollowCheck] = try await client
            .from("follows")
            .select("follower_id")
            .eq("follower_id", value: currentUser.id)
            .eq("following_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - Feed
    
    func fetchRecentReviews() async throws -> [Review] {
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value
        
        return response
    }
    
    func fetchFollowingReviews(userId: UUID) async throws -> [Review] {
        // Get list of following user IDs
        let following = try await getFollowing(userId: userId)
        let followingIds = following.map { $0.id }
        
        guard !followingIds.isEmpty else {
            // If not following anyone, return empty or fallback to recent reviews
            return []
        }
        
        // Fetch reviews from followed users
        // Convert UUID array to String array for .in() method
        let userIdStrings = followingIds.map { $0.uuidString }
        let response: [Review] = try await client
            .from("reviews")
            .select()
            .in("user_id", values: userIdStrings)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        
        return response
    }

    // MARK: - Activity Feed
    
    /// Fetches a mixed activity feed for the current user:
    /// - track and album reviews from people they follow
    /// - new followers (people who started following them)
    func fetchActivityFeed(limitPerType: Int = 30) async throws -> [ActivityItem] {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "Spectrum", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        struct FollowRelation: Codable {
            let follower_id: UUID
            let following_id: UUID
            let created_at: Date
        }
        
        // 1. Load follow relationships
        let followingRelations: [FollowRelation]
        do {
            followingRelations = try await client
                .from("follows")
                .select("follower_id,following_id,created_at")
                .eq("follower_id", value: currentUser.id)
                .execute()
                .value
        } catch {
            print("Activity: failed to load following relations:", error)
            followingRelations = []
        }
        
        let followerRelations: [FollowRelation]
        do {
            followerRelations = try await client
                .from("follows")
                .select("follower_id,following_id,created_at")
                .eq("following_id", value: currentUser.id)
                .execute()
                .value
        } catch {
            print("Activity: failed to load follower relations:", error)
            followerRelations = []
        }
        
        let followingIds = followingRelations.map { $0.following_id }
        let followerIds = followerRelations.map { $0.follower_id }
        
        // 2. Load profiles for all related users in a single query
        let allActorIds = Array(Set(followingIds + followerIds))
        let actorIdStrings = allActorIds.map { $0.uuidString }
        
        var profilesById: [UUID: Profile] = [:]
        if !actorIdStrings.isEmpty {
            do {
                let profileResponse: [Profile] = try await client
                    .from("profiles")
                    .select()
                    .in("id", values: actorIdStrings)
                    .execute()
                    .value
                for profile in profileResponse {
                    profilesById[profile.id] = profile
                }
            } catch {
                print("Activity: failed to load profiles:", error)
            }
        }
        
        // 3. Load reviews from people the user follows
        var activityItems: [ActivityItem] = []
        if !followingIds.isEmpty {
            let followingIdStrings = followingIds.map { $0.uuidString }
            
            // Track reviews
            let trackReviews: [Review]
            do {
                trackReviews = try await client
                    .from("reviews")
                    .select()
                    .in("user_id", values: followingIdStrings)
                    .order("created_at", ascending: false)
                    .limit(limitPerType)
                    .execute()
                    .value
            } catch {
                print("Activity: failed to load track reviews:", error)
                trackReviews = []
            }
            
            for review in trackReviews {
                let profile = profilesById[review.userId]
                let item = ActivityItem(
                    id: review.id,
                    type: .trackReview,
                    actorId: review.userId,
                    actorUsername: profile?.username,
                    actorAvatarUrl: profile?.avatarUrl,
                    targetId: String(review.itunesTrackId),
                    targetName: nil,
                    rating: review.rating,
                    vibeColor: review.vibeColor,
                    reviewText: review.reviewText,
                    createdAt: review.createdAt
                )
                activityItems.append(item)
            }
            
            // Album reviews
            let albumReviews: [AlbumReview]
            do {
                albumReviews = try await client
                    .from("album_reviews")
                    .select()
                    .in("user_id", values: followingIdStrings)
                    .order("created_at", ascending: false)
                    .limit(limitPerType)
                    .execute()
                    .value
            } catch {
                print("Activity: failed to load album reviews:", error)
                albumReviews = []
            }
            
            for review in albumReviews {
                let profile = profilesById[review.userId]
                let item = ActivityItem(
                    id: review.id,
                    type: .albumReview,
                    actorId: review.userId,
                    actorUsername: profile?.username,
                    actorAvatarUrl: profile?.avatarUrl,
                    targetId: String(review.itunesCollectionId),
                    targetName: nil,
                    rating: review.rating,
                    vibeColor: review.vibeColor,
                    reviewText: review.reviewText,
                    createdAt: review.createdAt
                )
                activityItems.append(item)
            }
        }
        
        // 4. New followers
        for relation in followerRelations {
            guard relation.follower_id != currentUser.id else { continue }
            let profile = profilesById[relation.follower_id]
            let item = ActivityItem(
                id: UUID(),
                type: .newFollower,
                actorId: relation.follower_id,
                actorUsername: profile?.username,
                actorAvatarUrl: profile?.avatarUrl,
                targetId: currentUser.id.uuidString,
                targetName: nil,
                rating: nil,
                vibeColor: nil,
                reviewText: nil,
                createdAt: relation.created_at
            )
            activityItems.append(item)
        }
        
        // 5. Sort by date, newest first
        return activityItems.sorted { $0.createdAt > $1.createdAt }
    }
}
