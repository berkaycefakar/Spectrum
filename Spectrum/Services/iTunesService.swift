import Foundation

class iTunesService {
    static let shared = iTunesService()
    private let baseURL = "https://itunes.apple.com"

    private init() {}

    /// Searches iTunes for tracks matching the query.
    func search(query: String) async throws -> [Track] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?term=\(encodedQuery)&media=music&entity=song&limit=20") else {
            throw URLError(.badURL)
        }

        let data = try await fetch(url: url)
        return try JSONDecoder().decode(iTunesResponse.self, from: data).results
    }

    /// Searches iTunes for albums matching the query.
    func searchAlbums(query: String) async throws -> [Album] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?term=\(encodedQuery)&media=music&entity=album&limit=20") else {
            throw URLError(.badURL)
        }

        let data = try await fetch(url: url)
        return try JSONDecoder().decode(iTunesAlbumResponse.self, from: data).results
    }

    /// Fetches a specific track by its iTunes ID (Critical for "Zero-Metadata" policy).
    func fetchTrack(id: Int64) async throws -> Track? {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(id)") else {
            throw URLError(.badURL)
        }

        let data = try await fetch(url: url)
        return try JSONDecoder().decode(iTunesResponse.self, from: data).results.first
    }

    /// Fetch all tracks that belong to an album (by collectionId).
    func fetchTracksForAlbum(albumId: Int64) async throws -> [Track] {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(albumId)&entity=song&limit=200") else {
            throw URLError(.badURL)
        }

        let data = try await fetch(url: url)
        return try JSONDecoder().decode(iTunesLookupResponse.self, from: data).results.compactMap { $0.asTrack }
    }

    /// Fetch a single album by collection ID (for profile album grid).
    func fetchAlbum(collectionId: Int64) async throws -> Album? {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(collectionId)") else {
            throw URLError(.badURL)
        }

        let data = try await fetch(url: url)
        return try JSONDecoder().decode(iTunesAlbumLookupResponse.self, from: data).results.first
    }

    // MARK: - Private

    private func fetch(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return data
    }
}

/// Lookup response: first item can be collection, rest are tracks. We only keep tracks.
private struct iTunesLookupResponse: Decodable {
    let results: [iTunesLookupItem]
}

private struct iTunesLookupItem: Decodable {
    let wrapperType: String?
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let artworkUrl100: String?
    let previewUrl: String?
    let collectionId: Int64?
    
    var asTrack: Track? {
        guard wrapperType == "track", let id = trackId, let title = trackName, let artist = artistName, let art = artworkUrl100 else { return nil }
        return Track(
            id: id,
            title: title,
            artist: artist,
            artworkUrl100: art,
            previewUrl: previewUrl,
            collectionId: collectionId
        )
    }
}

private struct iTunesAlbumLookupResponse: Decodable {
    let results: [Album]
}

struct iTunesAlbumResponse: Decodable {
    let results: [Album]
}
