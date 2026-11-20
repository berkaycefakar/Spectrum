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
        case .song: String(localized: "Song", bundle: appStringsBundle)
        case .album: String(localized: "Album", bundle: appStringsBundle)
        case .artist: String(localized: "Artist", bundle: appStringsBundle)
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
    /// A photo the owner picked as the cover (public URL in `list-covers`). Nil shows the
    /// list's own records instead.
    var coverUrl: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case coverUrl = "cover_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension MusicList {
    /// Only this project's `list-covers` bucket, under the owner's folder: any other URL is
    /// dropped on read, so a list can't make every viewer fetch an image from a server of the
    /// owner's choosing (and log their IP).
    static let coverURLPrefix = "https://ysgbqlltzdhgsezukxxm.supabase.co/storage/v1/object/public/list-covers/"

    // In an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let userId = try c.decode(UUID.self, forKey: .userId)
        let rawCover = try c.decodeIfPresent(String.self, forKey: .coverUrl)
        let allowed = (Self.coverURLPrefix + userId.uuidString + "/").lowercased()
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            userId: userId,
            title: try c.decode(String.self, forKey: .title),
            description: try c.decodeIfPresent(String.self, forKey: .description),
            isPublic: try c.decode(Bool.self, forKey: .isPublic),
            createdAt: try c.decode(Date.self, forKey: .createdAt),
            updatedAt: try c.decode(Date.self, forKey: .updatedAt),
            coverUrl: rawCover.flatMap { $0.lowercased().hasPrefix(allowed) ? $0 : nil }
        )
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
