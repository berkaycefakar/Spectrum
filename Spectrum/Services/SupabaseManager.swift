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
        
        try await client
            .from("reviews")
            .insert(newReview)
            .execute()
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
        
        try await client
            .from("artist_reviews")
            .insert(newReview)
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
        
        // Use proper Supabase insert format
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
        let response: [Follow] = try await client
            .from("follows")
            .select()
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        let followingIds = response.map { $0.followingId }
        var profiles: [Profile] = []
        
        for id in followingIds {
            if let profile = try? await getProfile(userId: id) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }
    
    func getFollowers(userId: UUID) async throws -> [Profile] {
        let response: [Follow] = try await client
            .from("follows")
            .select()
            .eq("following_id", value: userId)
            .execute()
            .value
        
        let followerIds = response.map { $0.followerId }
        var profiles: [Profile] = []
        
        for id in followerIds {
            if let profile = try? await getProfile(userId: id) {
                profiles.append(profile)
            }
        }
        
        return profiles
    }
    
    func isFollowing(userId: UUID) async throws -> Bool {
        guard let currentUser = try await getCurrentUser() else {
            return false
        }
        
        let response: [Follow] = try await client
            .from("follows")
            .select()
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
}
