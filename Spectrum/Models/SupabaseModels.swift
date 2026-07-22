import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let avatarUrl: String?
    let bio: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case bio
    }
}

struct Review: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itunesTrackId: Int64
    let spotifyTrackId: String?
    let rating: Int
    let reviewText: String?
    let vibeColor: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itunesTrackId = "itunes_track_id"
        case spotifyTrackId = "spotify_track_id"
        case rating
        case reviewText = "review_text"
        case vibeColor = "vibe_color"
        case createdAt = "created_at"
    }
}

// Encodable struct for creating a new review
struct NewReview: Encodable {
    let user_id: UUID
    let itunes_track_id: Int64
    let rating: Int
    let review_text: String
    let vibe_color: String
}

// Encodable struct for updating a profile
struct ProfileUpdate: Encodable {
    let username: String
    let bio: String
}

// MARK: - Album Reviews

struct AlbumReview: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itunesCollectionId: Int64
    let rating: Int
    let reviewText: String?
    let vibeColor: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itunesCollectionId = "itunes_collection_id"
        case rating
        case reviewText = "review_text"
        case vibeColor = "vibe_color"
        case createdAt = "created_at"
    }
}

struct NewAlbumReview: Encodable {
    let user_id: UUID
    let itunes_collection_id: Int64
    let rating: Int
    let review_text: String
    let vibe_color: String
}

// MARK: - Artist Reviews

struct ArtistReview: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let artistName: String
    let rating: Int
    let reviewText: String?
    let vibeColor: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case artistName = "artist_name"
        case rating
        case reviewText = "review_text"
        case vibeColor = "vibe_color"
        case createdAt = "created_at"
    }
}

struct NewArtistReview: Encodable {
    let user_id: UUID
    let artist_name: String
    let rating: Int
    let review_text: String
    let vibe_color: String
}

// MARK: - Follows

struct Follow: Codable, Identifiable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

// MARK: - Activity

enum ActivityType: String, Codable {
    case trackReview = "track_review"
    case albumReview = "album_review"
    case newFollower = "new_follower"
}

struct ActivityItem: Codable, Identifiable {
    let id: UUID
    let type: ActivityType
    
    let actorId: UUID
    let actorUsername: String?
    let actorAvatarUrl: String?
    
    /// Target can be a track/album ID or a user ID, depending on type.
    let targetId: String?
    let targetName: String?
    
    let rating: Int?
    let vibeColor: String?
    let reviewText: String?
    
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case actorId = "actor_id"
        case actorUsername = "actor_username"
        case actorAvatarUrl = "actor_avatar_url"
        case targetId = "target_id"
        case targetName = "target_name"
        case rating
        case vibeColor = "vibe_color"
        case reviewText = "review_text"
        case createdAt = "created_at"
    }
}
