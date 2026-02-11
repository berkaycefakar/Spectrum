import Foundation

struct Track: Identifiable, Decodable {
    let id: Int
    let title: String
    let artist: String
    let artworkUrl100: String
    let previewUrl: String?
    /// Optional album (collection) identifier – used for album detail flows.
    let collectionId: Int64?
    
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
        collectionId: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkUrl100 = artworkUrl100
        self.previewUrl = previewUrl
        self.collectionId = collectionId
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
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case title = "trackName"
        case artist = "artistName"
        case artworkUrl100 = "artworkUrl100"
        case previewUrl
        case collectionId
    }
}

struct iTunesResponse: Decodable {
    let results: [Track]
}
