import SwiftUI

/// The streaming services a song can be opened in.
enum StreamingService: String, CaseIterable, Identifiable {
    case appleMusic, spotify, youtubeMusic

    var id: String { rawValue }

    var name: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        case .youtubeMusic: "YouTube Music"
        }
    }

    /// Apple Music opens the exact song. The others open a search for it: their universal
    /// links hand off to the app when it's installed. (song.link's API, which mapped ids
    /// across services, closed its free tier.)
    fileprivate func url(for track: Track) -> URL? {
        let query = "\(track.title) \(track.artist)"
        switch self {
        case .appleMusic:
            return track.appleMusicLink
        case .spotify:
            let path = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            return URL(string: "https://open.spotify.com/search/\(path)")
        case .youtubeMusic:
            var c = URLComponents(string: "https://music.youtube.com/search")
            c?.queryItems = [URLQueryItem(name: "q", value: query)]
            return c?.url
        }
    }
}

/// Share button for a song: open it in Apple Music, Spotify or YouTube Music, or send a
/// song.link URL that lets the person receiving it pick their own service.
struct ListenOnMenu<Label: View>: View {
    let track: Track
    @ViewBuilder var label: () -> Label

    @Environment(\.openURL) private var openURL

    private var shareURL: URL {
        // An integer id always makes a valid URL.
        URL(string: "https://song.link/i/\(track.id)")!
    }

    var body: some View {
        Menu {
            Section(String(localized: "Listen on", bundle: appStringsBundle)) {
                ForEach(StreamingService.allCases) { service in
                    Button(service.name) { open(service) }
                }
            }
            ShareLink(
                item: shareURL,
                subject: Text(track.title),
                message: Text("\(track.title) — \(track.artist)")
            ) {
                SwiftUI.Label(String(localized: "Share link", bundle: appStringsBundle), systemImage: "square.and.arrow.up")
            }
        } label: {
            label()
        }
    }

    private func open(_ service: StreamingService) {
        if let url = service.url(for: track) { openURL(url) }
    }
}
