import Foundation

struct Profile: Codable, Identifiable {
    let id: UUID
    let username: String?
    let avatarUrl: String?
    let bio: String?
    /// Up to four Apple collection ids, in shelf order. Optional so a row read before the
    /// showcase migration ran still decodes.
    var favoriteAlbumIds: [Int64]? = nil
    /// Album whose artwork fills the profile banner; nil draws it from the user's vibes.
    var coverAlbumId: Int64? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case bio
        case favoriteAlbumIds = "favorite_album_ids"
        case coverAlbumId = "cover_album_id"
    }
}

extension Profile {
    /// Where avatars live: this project's public `avatars` bucket. Anything else in
    /// `avatar_url` is dropped on read, so a profile can't make every viewer's phone fetch an
    /// image from a server of its choosing (and log their IP). The database enforces the same
    /// rule (`profiles_avatar_url_own_bucket`); this guards rows from before it.
    static let avatarURLPrefix = "https://ysgbqlltzdhgsezukxxm.supabase.co/storage/v1/object/public/avatars/"

    static func sanitizedAvatarURL(_ raw: String?, owner: UUID) -> String? {
        guard let raw else { return nil }
        let allowed = (avatarURLPrefix + owner.uuidString).lowercased()
        return raw.lowercased().hasPrefix(allowed) ? raw : nil
    }

    // In an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        self.init(
            id: id,
            username: try c.decodeIfPresent(String.self, forKey: .username),
            avatarUrl: Self.sanitizedAvatarURL(try c.decodeIfPresent(String.self, forKey: .avatarUrl), owner: id),
            bio: try c.decodeIfPresent(String.self, forKey: .bio),
            favoriteAlbumIds: try c.decodeIfPresent([Int64].self, forKey: .favoriteAlbumIds),
            coverAlbumId: try c.decodeIfPresent(Int64.self, forKey: .coverAlbumId)
        )
    }

    func withShowcase(favorites: [Int64], cover: Int64?) -> Profile {
        var copy = self
        copy.favoriteAlbumIds = favorites
        copy.coverAlbumId = cover
        return copy
    }
}

struct Review: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let itunesTrackId: Int64
    let spotifyTrackId: String?
    let rating: Double
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
    let rating: Double
    let review_text: String
    let vibe_color: String
}

/// The mutable part of any review row (track, album or artist). Editing a log rewrites
/// exactly these three columns and leaves user/target/created_at alone.
struct ReviewUpdate: Encodable {
    let rating: Double
    let review_text: String
    let vibe_color: String
}

// Encodable struct for updating a profile
struct ProfileUpdate: Encodable {
    let username: String
    let bio: String
}

// Update including avatar. `avatar_url` is omitted from the payload when nil so an update
// without a new photo doesn't wipe the existing avatar.
struct ProfileUpdateFull: Encodable {
    let username: String
    let bio: String
    let avatar_url: String?

    enum CodingKeys: String, CodingKey {
        case username, bio, avatar_url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(bio, forKey: .bio)
        if let avatar_url { try container.encode(avatar_url, forKey: .avatar_url) }
    }
}

// MARK: - Album Reviews

struct AlbumReview: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itunesCollectionId: Int64
    let rating: Double
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
    let rating: Double
    let review_text: String
    let vibe_color: String
}

// MARK: - Artist Reviews

struct ArtistReview: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let artistName: String
    let rating: Double
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
    let rating: Double
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
    
    let rating: Double?
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

    /// Which kind of content a report filed from this row is about. A follow has no text to
    /// report, but the *actor* can still be reported, so it maps to their profile.
    var reportedContentType: ReportedContentType {
        switch type {
        case .trackReview: return .songReview
        case .albumReview: return .albumReview
        case .newFollower: return .profile
        }
    }
}


/// A written reply under a log.
struct ReviewComment: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let contentType: String
    let contentId: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentType = "content_type"
        case contentId = "content_id"
        case body
        case createdAt = "created_at"
    }
}
