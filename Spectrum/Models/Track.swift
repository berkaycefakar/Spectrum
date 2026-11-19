import Foundation

/// A single credited artist on a track. Songs can have several (collaborations, features),
/// and each should be independently tappable.
struct ArtistRef: Identifiable, Hashable {
    let artistId: String?   // MusicKit artist id; nil when only the name is known
    let name: String
    var id: String { artistId ?? name }
}

struct Track: Identifiable, Codable, Hashable {
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
    /// Canonical `music.apple.com` page for the song, straight from MusicKit. Only present on
    /// tracks that came back from a catalog request; `appleMusicLink` covers the rest.
    let appleMusicUrl: String?
    /// Who wrote it. The closest thing music has to Letterboxd's director field, and the
    /// reason a classical or jazz log can say something a rating can't.
    let composerName: String?
    /// Apple's explicit marking. `nil` when the catalog doesn't say.
    let isExplicit: Bool?

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
    
    /// The link to hand to a share sheet.
    ///
    /// This used to be `spotify:search:<artist> <title>` — a URI scheme, which is not a
    /// tappable link in Messages or WhatsApp, dies when the recipient has no Spotify, and
    /// pointed at a competitor of the catalog every track here comes from. MusicKit already
    /// carries the canonical page; `music.apple.com/song/<id>` is the documented fallback for
    /// tracks rebuilt from a stored id, and Apple redirects it to the viewer's storefront.
    var appleMusicLink: URL? {
        if let appleMusicUrl, let url = URL(string: appleMusicUrl) { return url }
        return URL(string: "https://music.apple.com/song/\(id)")
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
        artists: [ArtistRef] = [],
        appleMusicUrl: String? = nil,
        composerName: String? = nil,
        isExplicit: Bool? = nil
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
        self.appleMusicUrl = appleMusicUrl
        self.composerName = composerName
        self.isExplicit = isExplicit
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
        // Stored/MusicKit JSON carries it as a string, the iTunes lookup as a number. Reading
        // only the string form made every iTunes row fail to decode, so the feed's fast path
        // returned nothing and every card waited on MusicKit instead.
        if let text = try? container.decodeIfPresent(String.self, forKey: .artistId) {
            self.artistId = text
        } else {
            self.artistId = (try? container.decodeIfPresent(Int64.self, forKey: .artistId)).flatMap { $0.map(String.init) }
        }
        self.artists = []  // populated from MusicKit relationships, not JSON
        self.appleMusicUrl = try container.decodeIfPresent(String.self, forKey: .appleMusicUrl)
        // MusicKit-only: nothing in the stored JSON carries these.
        self.composerName = nil
        self.isExplicit = nil
    }
    
    /// Mirrors `init(from:)` so a track survives the feed's disk cache. The credited-artist
    /// list and the MusicKit-only fields are not stored; the catalog fills them in again.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(artist, forKey: .artist)
        try c.encode(artworkUrl100, forKey: .artworkUrl100)
        try c.encodeIfPresent(previewUrl, forKey: .previewUrl)
        try c.encodeIfPresent(collectionId, forKey: .collectionId)
        try c.encodeIfPresent(genreNames, forKey: .genreNames)
        try c.encodeIfPresent(durationInMillis, forKey: .durationInMillis)
        try c.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try c.encodeIfPresent(artistId, forKey: .artistId)
        try c.encodeIfPresent(appleMusicUrl, forKey: .appleMusicUrl)
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
        case appleMusicUrl
    }
}
