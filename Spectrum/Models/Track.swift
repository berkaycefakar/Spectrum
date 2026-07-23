import Foundation

/// A single credited artist on a track. Songs can have several (collaborations, features),
/// and each should be independently tappable.
struct ArtistRef: Identifiable, Hashable {
    let artistId: String?   // MusicKit artist id; nil when only the name is known
    let name: String
    var id: String { artistId ?? name }
}

struct Track: Identifiable, Decodable {
    let id: Int
    let title: String
    let artist: String
    let artworkUrl100: String
    let previewUrl: String?
    /// Optional album (collection) identifier – used for album detail flows.
    let collectionId: Int64?

    // MusicKit-sourced fields
    let genreNames: [String]?
    let durationInMillis: Int?
    let releaseDate: Date?
    let artistId: String?
    /// All credited artists (for collaborations). Empty when only the combined name is known.
    let artists: [ArtistRef]

    /// Artists to display/link. Falls back to the single primary artist when the per-artist
    /// list isn't populated (e.g. album track lists or legacy data).
    var displayArtists: [ArtistRef] {
        artists.isEmpty ? [ArtistRef(artistId: artistId, name: artist)] : artists
    }

    // Computed property for the "Liquid Glass" high-res image
    var artworkUrl600: URL? {
        let highResString = artworkUrl100.replacingOccurrences(of: "100x100", with: "600x600")
        return URL(string: highResString)
    }
    
    // Spotify Deep Link Fallback
    var spotifyDeepLink: URL? {
        let query = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "spotify:search:\(query)")
    }
    
    /// Convenience initializer used throughout the UI (previews, mock data).
    /// `collectionId` opsiyonel, verilmezse `nil` olur.
    init(
        id: Int,
        title: String,
        artist: String,
        artworkUrl100: String,
        previewUrl: String?,
        collectionId: Int64? = nil,
        genreNames: [String]? = nil,
        durationInMillis: Int? = nil,
        releaseDate: Date? = nil,
        artistId: String? = nil,
        artists: [ArtistRef] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkUrl100 = artworkUrl100
        self.previewUrl = previewUrl
        self.collectionId = collectionId
        self.genreNames = genreNames
        self.durationInMillis = durationInMillis
        self.releaseDate = releaseDate
        self.artistId = artistId
        self.artists = artists
    }
    
    /// Custom Decodable implementation to support the new `collectionId` field
    /// while koruyarak mevcut JSON mapping'i.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.artworkUrl100 = try container.decode(String.self, forKey: .artworkUrl100)
        self.previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)
        self.collectionId = try container.decodeIfPresent(Int64.self, forKey: .collectionId)
        self.genreNames = try container.decodeIfPresent([String].self, forKey: .genreNames)
        self.durationInMillis = try container.decodeIfPresent(Int.self, forKey: .durationInMillis)
        self.releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        self.artists = []  // populated from MusicKit relationships, not JSON
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case title = "trackName"
        case artist = "artistName"
        case artworkUrl100 = "artworkUrl100"
        case previewUrl
        case collectionId
        case genreNames
        case durationInMillis
        case releaseDate
        case artistId
    }
}

struct iTunesResponse: Decodable {
    let results: [Track]
}
