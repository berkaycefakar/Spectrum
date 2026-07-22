import Foundation

struct Artist: Identifiable {
    let id: String // MusicItemID as string
    let name: String
    let artworkUrl: URL?
    let genres: [String]
    let topSongs: [Track]
    let albums: [Album]
    let editorialNotes: String?

    init(
        id: String,
        name: String,
        artworkUrl: URL? = nil,
        genres: [String] = [],
        topSongs: [Track] = [],
        albums: [Album] = [],
        editorialNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.artworkUrl = artworkUrl
        self.genres = genres
        self.topSongs = topSongs
        self.albums = albums
        self.editorialNotes = editorialNotes
    }
}
