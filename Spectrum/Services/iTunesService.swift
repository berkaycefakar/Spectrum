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
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return response.results
    }
    
    /// Searches iTunes for albums matching the query.
    func searchAlbums(query: String) async throws -> [Album] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?term=\(encodedQuery)&media=music&entity=album&limit=20") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesAlbumResponse.self, from: data)
        return response.results
    }
    
    /// Fetches a specific track by its iTunes ID (Critical for "Zero-Metadata" policy).
    func fetchTrack(id: Int64) async throws -> Track? {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
        return response.results.first
    }
    
    /// Fetch all tracks that belong to an album (by collectionId).
    /// iTunes lookup returns one collection object + N track objects; we decode only tracks.
    func fetchTracksForAlbum(albumId: Int64) async throws -> [Track] {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(albumId)&entity=song&limit=200") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesLookupResponse.self, from: data)
        return response.results.compactMap { $0.asTrack }
    }
    
    /// Fetch a single album by collection ID (for profile album grid).
    func fetchAlbum(collectionId: Int64) async throws -> Album? {
        guard let url = URL(string: "\(baseURL)/lookup?id=\(collectionId)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesAlbumLookupResponse.self, from: data)
        return response.results.first
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
