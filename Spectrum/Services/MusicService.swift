import Foundation
import MusicKit

/// MusicKit-based service replacing iTunesService.
/// Uses Apple MusicKit framework for catalog search and lookup.
class MusicService {
    static let shared = MusicService()

    private init() {}

    // MARK: - Authorization

    /// Request MusicKit authorization. Catalog search works without authorization,
    /// but requesting it is best practice for full MusicKit features.
    @discardableResult
    func requestMusicAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }

    // MARK: - Search: Tracks

    func search(query: String) async throws -> [Track] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return response.songs.compactMap { mapSongToTrack($0) }
    }

    // MARK: - Search: Albums

    func searchAlbums(query: String) async throws -> [Album] {
        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Album.self])
        request.limit = 20
        let response = try await request.response()
        return response.albums.compactMap { mapMusicKitAlbumToAlbum($0) }
    }

    // MARK: - Search: Artists

    func searchArtists(query: String) async throws -> [Artist] {
        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Artist.self])
        request.limit = 20
        let response = try await request.response()
        return response.artists.compactMap { mapMusicKitArtistToArtist($0) }
    }

    // MARK: - Fetch: Single Track by ID

    func fetchTrack(id: Int64) async throws -> Track? {
        let musicItemId = MusicItemID(String(id))
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemId)
        let response = try await request.response()
        guard let song = response.items.first else { return nil }
        return mapSongToTrack(song)
    }

    // MARK: - Fetch: Single Album by ID

    func fetchAlbum(collectionId: Int64) async throws -> Album? {
        let musicItemId = MusicItemID(String(collectionId))
        let request = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: musicItemId)
        let response = try await request.response()
        guard let album = response.items.first else { return nil }
        return mapMusicKitAlbumToAlbum(album)
    }

    // MARK: - Fetch: Single Artist by ID

    func fetchArtist(id: String) async throws -> Artist? {
        let musicItemId = MusicItemID(id)
        var request = MusicCatalogResourceRequest<MusicKit.Artist>(matching: \.id, equalTo: musicItemId)
        request.properties = [.topSongs, .albums, .genres]
        let response = try await request.response()
        guard let artist = response.items.first else { return nil }
        return mapMusicKitArtistToArtistDetailed(artist)
    }

    // MARK: - Fetch: Tracks for Album

    func fetchTracksForAlbum(albumId: Int64) async throws -> [Track] {
        let musicItemId = MusicItemID(String(albumId))
        var request = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: musicItemId)
        request.properties = [.tracks]
        let response = try await request.response()
        guard let album = response.items.first, let tracks = album.tracks else { return [] }
        return tracks.compactMap { mapMusicKitTrackToTrack($0, albumId: albumId) }
    }

    // MARK: - Mapping: MusicKit.Track (album track) -> Track

    private func mapMusicKitTrackToTrack(_ mkTrack: MusicKit.Track, albumId: Int64? = nil) -> Track {
        let artworkUrl100 = mkTrack.artwork?.url(width: 100, height: 100)?.absoluteString ?? ""
        let previewUrl = mkTrack.previewAssets?.first?.url?.absoluteString

        return Track(
            id: Int(mkTrack.id.rawValue) ?? 0,
            title: mkTrack.title,
            artist: mkTrack.artistName,
            artworkUrl100: artworkUrl100,
            previewUrl: previewUrl,
            collectionId: albumId,
            durationInMillis: mkTrack.duration.map { Int($0 * 1000) }
        )
    }

    // MARK: - Mapping: MusicKit Song -> Track

    private func mapSongToTrack(_ song: Song) -> Track {
        // Build artwork URL string (100x100 for base, artworkUrl600 computed property handles upscale)
        let artworkUrl100 = song.artwork?.url(width: 100, height: 100)?.absoluteString ?? ""

        // Preview URL from MusicKit
        let previewUrl = song.previewAssets?.first?.url?.absoluteString

        // Collection (album) ID: MusicKit stores album relationship
        let collectionId: Int64? = {
            if let albumIdStr = song.albums?.first?.id.rawValue, let numericId = Int64(albumIdStr) {
                return numericId
            }
            return nil
        }()

        // Artist ID
        let artistId: String? = song.artists?.first?.id.rawValue

        return Track(
            id: Int(song.id.rawValue) ?? 0,
            title: song.title,
            artist: song.artistName,
            artworkUrl100: artworkUrl100,
            previewUrl: previewUrl,
            collectionId: collectionId,
            genreNames: song.genreNames,
            durationInMillis: song.duration.map { Int($0 * 1000) },
            releaseDate: song.releaseDate,
            artistId: artistId
        )
    }

    // MARK: - Mapping: MusicKit Album -> Album

    private func mapMusicKitAlbumToAlbum(_ mkAlbum: MusicKit.Album) -> Album {
        let artworkUrl100 = mkAlbum.artwork?.url(width: 100, height: 100)?.absoluteString ?? ""
        let artistId: String? = mkAlbum.artists?.first?.id.rawValue

        return Album(
            id: Int64(mkAlbum.id.rawValue) ?? 0,
            title: mkAlbum.title,
            artist: mkAlbum.artistName,
            artworkUrl100: artworkUrl100,
            trackCount: mkAlbum.trackCount,
            releaseDate: mkAlbum.releaseDate,
            genreNames: mkAlbum.genreNames,
            editorialNotes: mkAlbum.editorialNotes?.standard ?? mkAlbum.editorialNotes?.short,
            artistId: artistId
        )
    }

    // MARK: - Mapping: MusicKit Artist -> Artist (basic, from search)

    private func mapMusicKitArtistToArtist(_ mkArtist: MusicKit.Artist) -> Artist {
        let artworkUrl = mkArtist.artwork?.url(width: 600, height: 600)

        return Artist(
            id: mkArtist.id.rawValue,
            name: mkArtist.name,
            artworkUrl: artworkUrl,
            genres: mkArtist.genres?.map(\.name) ?? [],
            editorialNotes: mkArtist.editorialNotes?.standard ?? mkArtist.editorialNotes?.short
        )
    }

    // MARK: - Mapping: MusicKit Artist -> Artist (detailed, with songs and albums)

    private func mapMusicKitArtistToArtistDetailed(_ mkArtist: MusicKit.Artist) -> Artist {
        let artworkUrl = mkArtist.artwork?.url(width: 600, height: 600)

        let topSongs: [Track] = mkArtist.topSongs?.prefix(10).compactMap { mapSongToTrack($0) } ?? []
        let albums: [Album] = mkArtist.albums?.prefix(20).compactMap { mapMusicKitAlbumToAlbum($0) } ?? []

        return Artist(
            id: mkArtist.id.rawValue,
            name: mkArtist.name,
            artworkUrl: artworkUrl,
            genres: mkArtist.genres?.map(\.name) ?? [],
            topSongs: topSongs,
            albums: albums,
            editorialNotes: mkArtist.editorialNotes?.standard ?? mkArtist.editorialNotes?.short
        )
    }
}
