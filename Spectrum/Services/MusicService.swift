import Foundation
import MusicKit

/// MusicKit-based service replacing iTunesService.
/// Uses Apple MusicKit framework for catalog search and lookup.
class MusicService {
    static let shared = MusicService()

    private init() {}

    private let artistBriefCache = ArtistBriefCache()

    // MARK: - Search: Tracks

    func search(query: String) async throws -> [Track] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 20
            let response = try await request.response()

            // Search responses don't include relationships, so `song.albums` / `song.artists`
            // are always nil here and every result would map with a nil collectionId —
            // breaking navigation into the album. One batched resource request fills them in.
            let songs = await withRelationships(Array(response.songs))
            return songs.map { mapSongToTrack($0) }
        } catch {
            logFailure("search(query: \(query))", error)
            throw error
        }
    }

    /// Refetches songs with their album and artist relationships populated.
    /// Falls back to the originals if the follow-up request fails — partial data beats none.
    private func withRelationships(_ songs: [Song]) async -> [Song] {
        guard !songs.isEmpty else { return [] }

        do {
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songs.map(\.id))
            request.properties = [.albums, .artists]
            let response = try await request.response()

            // Preserve the relevance order the search returned; the resource request doesn't
            // guarantee it.
            let byId = Dictionary(uniqueKeysWithValues: response.items.map { ($0.id, $0) })
            return songs.map { byId[$0.id] ?? $0 }
        } catch {
            logFailure("withRelationships", error)
            return songs
        }
    }

    private func logFailure(_ context: String, _ error: Error) {
        debugLog("MusicKit failure in \(context): \(error)")
        if MusicAuthorization.currentStatus != .authorized {
            debugLog("  → authorization is \(MusicAuthorization.currentStatus). This is the likely cause.")
        }
    }

    // MARK: - Search: Albums

    func searchAlbums(query: String) async throws -> [Album] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Album.self])
            request.limit = 20
            let response = try await request.response()
            return response.albums.compactMap { mapMusicKitAlbumToAlbum($0) }
        } catch {
            logFailure("searchAlbums(query: \(query))", error)
            throw error
        }
    }

    // MARK: - Search: Artists

    func searchArtists(query: String) async throws -> [Artist] {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Artist.self])
            request.limit = 20
            let response = try await request.response()
            return response.artists.compactMap { mapMusicKitArtistToArtist($0) }
        } catch {
            logFailure("searchArtists(query: \(query))", error)
            throw error
        }
    }

    // MARK: - Lookup: Artists by name

    /// Resolves artist names to their photo + catalog id.
    ///
    /// `artist_reviews` rows only carry a name, so anything listing them (the profile's
    /// Artists tab) has no artwork to show. MusicKit has no batch "match by name" request, so
    /// this fans out one search per name concurrently and caches the results — the profile
    /// reloads on every save and would otherwise re-search the same handful of names forever.
    func fetchArtistBriefs(names: [String]) async -> [String: ArtistBrief] {
        let unique = Array(Set(names.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: ArtistBrief] = [:]
        var missing: [String] = []
        for name in unique {
            if let cached = await artistBriefCache.value(for: name) {
                result[name] = cached
            } else {
                missing.append(name)
            }
        }
        guard !missing.isEmpty else { return result }

        let fetched = await withTaskGroup(of: (String, ArtistBrief?).self) { group in
            for name in missing {
                group.addTask { (name, await self.searchArtistBrief(name: name)) }
            }
            var found: [String: ArtistBrief] = [:]
            for await (name, brief) in group {
                if let brief { found[name] = brief }
            }
            return found
        }

        for (name, brief) in fetched {
            await artistBriefCache.store(brief, for: name)
            result[name] = brief
        }
        return result
    }

    private func searchArtistBrief(name: String) async -> ArtistBrief? {
        do {
            var request = MusicCatalogSearchRequest(term: name, types: [MusicKit.Artist.self])
            request.limit = 5
            let response = try await request.response()

            // Prefer an exact name match: searching "Muse" also returns "Museum of Love", and
            // the top hit isn't always the artist the user actually logged.
            let artists = Array(response.artists)
            let match = artists.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
                ?? artists.first
            guard let match else { return nil }

            return ArtistBrief(
                id: match.id.rawValue,
                name: match.name,
                artworkUrl: match.artwork?.url(width: 300, height: 300)
            )
        } catch {
            logFailure("searchArtistBrief(name: \(name))", error)
            return nil
        }
    }

    // MARK: - Fetch: Single Track by ID

    func fetchTrack(id: Int64) async throws -> Track? {
        let musicItemId = MusicItemID(String(id))
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemId)
        request.properties = [.artists, .albums]
        let response = try await request.response()
        guard let song = response.items.first else { return nil }
        return mapSongToTrack(song)
    }

    // MARK: - Batch Fetch: Tracks by IDs

    /// Fetches many tracks in a single request instead of one round-trip per id.
    /// Feeds and profiles were fetching sequentially, which made them slow to populate.
    func fetchTracks(ids: [Int64]) async -> [Int64: Track] {
        guard !ids.isEmpty else { return [:] }
        do {
            let itemIds = ids.map { MusicItemID(String($0)) }
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: itemIds)
            request.properties = [.artists, .albums]
            let response = try await request.response()

            var result: [Int64: Track] = [:]
            for song in response.items {
                if let numericId = Int64(song.id.rawValue) {
                    result[numericId] = mapSongToTrack(song)
                }
            }
            return result
        } catch {
            logFailure("fetchTracks(ids:)", error)
            return [:]
        }
    }

    /// Batch album lookup, keyed by collection id.
    func fetchAlbums(ids: [Int64]) async -> [Int64: Album] {
        guard !ids.isEmpty else { return [:] }
        do {
            let itemIds = ids.map { MusicItemID(String($0)) }
            let request = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, memberOf: itemIds)
            let response = try await request.response()

            var result: [Int64: Album] = [:]
            for album in response.items {
                if let numericId = Int64(album.id.rawValue) {
                    result[numericId] = mapMusicKitAlbumToAlbum(album)
                }
            }
            return result
        } catch {
            logFailure("fetchAlbums(ids:)", error)
            return [:]
        }
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
        request.properties = [.topSongs, .albums, .genres, .similarArtists]
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

        // Individual credited artists (collaborations/features). Requires the `.artists`
        // relationship to be loaded; empty otherwise and the UI falls back to artistName.
        let artistRefs: [ArtistRef] = song.artists?.map {
            ArtistRef(artistId: $0.id.rawValue, name: $0.name)
        } ?? []
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
            artistId: artistId,
            artists: artistRefs
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

    /// A richer genre list than MusicKit's artist relationship gives on its own.
    ///
    /// `artist.genres` is usually a single broad bucket ("Pop"), because that's how Apple
    /// files the *artist*. The detail lives on their catalogue: the top songs and albums each
    /// carry their own genre names. Those get folded in, ranked by how often they appear, so
    /// an artist's page shows what they actually make rather than one generic label.
    private func combinedGenres(artistGenres: [String], songs: [Track], albums: [Album]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        func add(_ name: String) {
            // "Music" is Apple's catch-all parent genre — true of every record ever released.
            guard name.caseInsensitiveCompare("Music") != .orderedSame else { return }
            if seen.insert(name.lowercased()).inserted { ordered.append(name) }
        }

        // The artist's own genres stay pinned to the front — they're the most authoritative.
        artistGenres.forEach(add)

        // Everything else is ranked by frequency: a genre on 8 of 10 top songs describes the
        // artist far better than one that shows up on a single b-side.
        let catalogGenres = songs.flatMap { $0.genreNames ?? [] } + albums.flatMap { $0.genreNames ?? [] }
        var counts: [String: Int] = [:]
        var firstSpelling: [String: String] = [:]
        for name in catalogGenres {
            let key = name.lowercased()
            counts[key, default: 0] += 1
            if firstSpelling[key] == nil { firstSpelling[key] = name }
        }

        counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .compactMap { firstSpelling[$0.key] }
            .forEach(add)

        return Array(ordered.prefix(8))
    }

    // MARK: - Mapping: MusicKit Artist -> Artist (detailed, with songs and albums)

    private func mapMusicKitArtistToArtistDetailed(_ mkArtist: MusicKit.Artist) -> Artist {
        let artworkUrl = mkArtist.artwork?.url(width: 600, height: 600)

        let topSongs: [Track] = mkArtist.topSongs?.prefix(10).compactMap { mapSongToTrack($0) } ?? []

        // Newest first. MusicKit returns the albums relationship in its own editorial order,
        // which put decade-old records ahead of a release from last month — the opposite of
        // what someone opening an artist page is looking for. Sorted *before* the cap so the
        // twenty we keep are genuinely the twenty most recent.
        let albums: [Album] = Array(
            (mkArtist.albums?.compactMap { mapMusicKitAlbumToAlbum($0) } ?? [])
                .sorted(by: Album.newestFirst)
                .prefix(20)
        )

        // "Fans also like". Requires the `.similarArtists` property on the request; empty
        // otherwise, and the artist page simply hides the section.
        let similar: [ArtistBrief] = mkArtist.similarArtists?.prefix(20).map {
            ArtistBrief(
                id: $0.id.rawValue,
                name: $0.name,
                artworkUrl: $0.artwork?.url(width: 300, height: 300)
            )
        } ?? []

        return Artist(
            id: mkArtist.id.rawValue,
            name: mkArtist.name,
            artworkUrl: artworkUrl,
            genres: combinedGenres(
                artistGenres: mkArtist.genres?.map(\.name) ?? [],
                songs: topSongs,
                albums: albums
            ),
            topSongs: topSongs,
            albums: albums,
            editorialNotes: mkArtist.editorialNotes?.standard ?? mkArtist.editorialNotes?.short,
            similarArtists: similar
        )
    }
}

// MARK: - Artist Brief Cache

/// Name → artist lookups, kept for the process lifetime. An actor because `MusicService` is a
/// plain shared class that gets hit from several concurrent screen loads.
private actor ArtistBriefCache {
    private var storage: [String: ArtistBrief] = [:]

    func value(for name: String) -> ArtistBrief? { storage[name] }
    func store(_ brief: ArtistBrief, for name: String) { storage[name] = brief }
}
