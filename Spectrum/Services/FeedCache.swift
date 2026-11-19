import Foundation

/// The first page of the home feed, kept on disk so the next launch can draw it at once
/// while the fresh copy loads behind it. Keyed by user, and deleted on sign-out.
struct FeedSnapshot: Codable {
    let userId: UUID
    let reviews: [Review]
    let tracks: [Track]
    let profiles: [Profile]
    let showingRecent: Bool
}

enum FeedCache {
    private static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("home-feed-v1.json")
    }

    static func load(for userId: UUID) -> FeedSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(FeedSnapshot.self, from: data),
              snapshot.userId == userId else { return nil }
        return snapshot
    }

    static func save(_ snapshot: FeedSnapshot) {
        let target = url
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
