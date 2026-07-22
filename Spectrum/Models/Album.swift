import Foundation

/// Simple album representation — supports both iTunes JSON and MusicKit data
struct Album: Identifiable, Decodable {
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
        artistId: String? = nil
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
