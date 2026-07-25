import Foundation

/// Just enough of an artist to draw a row: photo + the id needed to open their page.
/// `artist_reviews` only stores the artist's *name*, so lists built from it have to resolve
/// artwork separately — this is what that resolution returns.
struct ArtistBrief: Identifiable, Hashable {
    let id: String
    let name: String
    let artworkUrl: URL?
}

struct Artist: Identifiable {
    let id: String // MusicItemID as string
    let name: String
    let artworkUrl: URL?
    let genres: [String]
    let topSongs: [Track]
    let albums: [Album]
    let editorialNotes: String?
    /// "Fans also like" — MusicKit's `similarArtists` relationship. Only populated by the
    /// detailed lookup (`fetchArtist(id:)`); search results leave it empty.
    let similarArtists: [ArtistBrief]

    init(
        id: String,
        name: String,
        artworkUrl: URL? = nil,
        genres: [String] = [],
        topSongs: [Track] = [],
        albums: [Album] = [],
        editorialNotes: String? = nil,
        similarArtists: [ArtistBrief] = []
    ) {
        self.id = id
        self.name = name
        self.artworkUrl = artworkUrl
        self.genres = genres
        self.topSongs = topSongs
        self.albums = albums
        self.editorialNotes = editorialNotes
        self.similarArtists = similarArtists
    }
}
