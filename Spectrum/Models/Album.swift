import Foundation

/// Simple iTunes album representation
struct Album: Identifiable, Decodable {
    let id: Int64              // collectionId
    let title: String          // collectionName
    let artist: String         // artistName
    let artworkUrl100: String  // artworkUrl100
    let trackCount: Int?
    
    var artworkUrl600: URL? {
        let highResString = artworkUrl100.replacingOccurrences(of: "100x100", with: "600x600")
        return URL(string: highResString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "collectionId"
        case title = "collectionName"
        case artist = "artistName"
        case artworkUrl100
        case trackCount
    }
}

