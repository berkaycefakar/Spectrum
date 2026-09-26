import Foundation

/// A playback-quality badge an album can carry.
///
/// These come free with every `MusicKit.Album` already being fetched — `audioVariants` — and
/// they are the difference between a page that looks like a database row and one that looks
/// like a music app. Ordered by how much people care: Atmos is a feature you seek out,
/// lossless is a preference, hi-res is a footnote.
enum AudioBadge: String, CaseIterable, Hashable {
    case dolbyAtmos
    case lossless
    case hiRes

    var label: String {
        switch self {
        case .dolbyAtmos: "Dolby Atmos"
        case .lossless: "Lossless"
        case .hiRes: "Hi-Res"
        }
    }

    var icon: String {
        switch self {
        case .dolbyAtmos: "airpods.max"
        case .lossless: "waveform"
        case .hiRes: "waveform.badge.plus"
        }
    }
}

/// Simple album representation — supports both iTunes JSON and MusicKit data
struct Album: Identifiable, Decodable, Hashable {
    let id: Int64              // collectionId
    let title: String          // collectionName
    let artist: String         // artistName
    let artworkUrl100: String  // artworkUrl100
    let trackCount: Int?

    // MusicKit-sourced fields
    let releaseDate: Date?
    let genreNames: [String]?
    let editorialNotes: String?
    let artistId: String?
    /// Apple's explicit/clean marking. `nil` when the catalog doesn't say.
    let isExplicit: Bool?
    /// Dolby Atmos / Lossless / Hi-Res badges, already filtered to the ones worth showing.
    let audioBadges: [AudioBadge]
    let recordLabel: String?

    var artworkUrl600: URL? {
        let highResString = artworkUrl100.replacingOccurrences(of: "100x100", with: "600x600")
        return URL(string: highResString)
    }

    init(
        id: Int64,
        title: String,
        artist: String,
        artworkUrl100: String,
        trackCount: Int? = nil,
        releaseDate: Date? = nil,
        genreNames: [String]? = nil,
        editorialNotes: String? = nil,
        artistId: String? = nil,
        isExplicit: Bool? = nil,
        audioBadges: [AudioBadge] = [],
        recordLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkUrl100 = artworkUrl100
        self.trackCount = trackCount
        self.releaseDate = releaseDate
        self.genreNames = genreNames
        self.editorialNotes = editorialNotes
        self.artistId = artistId
        self.isExplicit = isExplicit
        self.audioBadges = audioBadges
        self.recordLabel = recordLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.artworkUrl100 = try container.decode(String.self, forKey: .artworkUrl100)
        self.trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount)
        self.releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        self.genreNames = try container.decodeIfPresent([String].self, forKey: .genreNames)
        self.editorialNotes = try container.decodeIfPresent(String.self, forKey: .editorialNotes)
        self.artistId = try container.decodeIfPresent(String.self, forKey: .artistId)
        // MusicKit-only: nothing in the stored JSON carries these.
        self.isExplicit = nil
        self.audioBadges = []
        self.recordLabel = nil
    }

    /// The one ordering rule for "a list of albums": newest release first, undated releases
    /// last, ties broken by title so the order can't shuffle between two loads of the same
    /// data. Shared so the artist page, search and profile can't drift apart.
    nonisolated static func newestFirst(_ lhs: Album, _ rhs: Album) -> Bool {
        switch (lhs.releaseDate, rhs.releaseDate) {
        case let (l?, r?):
            // Same-day releases (very common for a deluxe edition shipped alongside the
            // standard one) fall back to the title rather than an arbitrary order.
            return l == r ? lhs.title < rhs.title : l > r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.title < rhs.title
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "collectionId"
        case title = "collectionName"
        case artist = "artistName"
        case artworkUrl100
        case trackCount
        case releaseDate
        case genreNames
        case editorialNotes
        case artistId
    }
}
