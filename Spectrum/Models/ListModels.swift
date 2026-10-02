import Foundation

/// What a list entry points at.
///
/// Songs and albums are keyed by their Apple numeric id; artists by name, because there is no
/// artist id column anywhere in this schema — `artist_reviews` has the same limitation, and
/// this deliberately matches it rather than inventing a second convention.
enum ListItemKind: String, Codable, CaseIterable, Sendable {
    case song
    case album
    case artist

    var label: String {
        switch self {
        case .song: String(localized: "Song")
        case .album: String(localized: "Album")
        case .artist: String(localized: "Artist")
        }
    }

    var icon: String {
        switch self {
        case .song: "music.note"
        case .album: "opticaldisc"
        case .artist: "person.fill"
        }
    }
}

struct MusicList: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String
    var description: String?
    var isPublic: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MusicListItem: Codable, Identifiable, Hashable {
    let id: UUID
    let listId: UUID
    let kind: ListItemKind
    /// Apple numeric id for songs and albums, the artist's name for artists.
    let contentRef: String
    var note: String?
    var position: Int
    let createdAt: Date

    /// Numeric id, for the two kinds that have one.
    var numericRef: Int64? {
        (kind == .song || kind == .album) ? Int64(contentRef) : nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case kind = "content_type"
        case contentRef = "content_ref"
        case note
        case position
        case createdAt = "created_at"
    }
}

// MARK: - Write payloads

struct NewMusicList: Encodable {
    let user_id: UUID
    let title: String
    let description: String?
    let is_public: Bool
}

struct MusicListUpdate: Encodable {
    let title: String
    let description: String?
    let is_public: Bool
    /// Set explicitly rather than left to the trigger: the trigger only fires on item
    /// changes, so renaming a list would otherwise leave it stale in the profile's ordering.
    let updated_at: Date
}

struct NewListItem: Encodable {
    let list_id: UUID
    let content_type: String
    let content_ref: String
    let note: String?
    let position: Int
}

/// A list plus the number of records in it — what the profile row needs and nothing more.
struct MusicListSummary: Identifiable, Hashable {
    let list: MusicList
    let itemCount: Int

    var id: UUID { list.id }
}
