import Foundation

/// Screenshot demo: `-spectrum.demo YES` fills every main screen from the fixtures below, with
/// no sign-in, no network writes and no Apple Music account. Compiled out of release builds.
enum DemoMode {
    static var isOn: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "spectrum.demo")
        #else
        false
        #endif
    }
}

#if DEBUG
enum DemoData {
    static let me = Profile(id: uuid(1), username: "berkay", avatarUrl: nil,
                            bio: "Albums for night drives. Rating everything I hear.",
                            favoriteAlbumIds: [1146195596, 1109714933, 1463409338, 1658650093],
                            coverAlbumId: 1146195596)

    static let friends: [Profile] = [
        Profile(id: uuid(2), username: "selin", avatarUrl: nil, bio: nil),
        Profile(id: uuid(3), username: "deniz", avatarUrl: nil, bio: nil),
        Profile(id: uuid(4), username: "ayse", avatarUrl: nil, bio: nil),
        Profile(id: uuid(5), username: "mert", avatarUrl: nil, bio: nil),
        Profile(id: uuid(6), username: "ece", avatarUrl: nil, bio: nil),
    ]

    static var profilesById: [UUID: Profile] {
        Dictionary(uniqueKeysWithValues: (friends + [me]).map { ($0.id, $0) })
    }

    static let tracks: [Track] = [
        Track(id: 1658650499, title: "Snooze", artist: "SZA", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/62/93/13/6293132e-20ff-67ab-3d1f-96bb6797a6ba/196589564955.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/b3/9b/ca/b39bca57-2627-1aec-77af-cbf551205394/mzaf_4430383240210492712.plus.aac.p.m4a", collectionId: 1658650093),
        Track(id: 1146195714, title: "Pink + White", artist: "Frank Ocean", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/bb/45/68/bb4568f3-68cd-619d-fbcb-4e179916545d/BlondCover-Final.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/ba/11/dc/ba11dccd-16d2-9cd8-13f0-85b73acc0a09/mzaf_1304250511099243436.plus.aac.p.m4a", collectionId: 1146195596),
        Track(id: 1440838060, title: "Let It Happen", artist: "Tame Impala", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/a8/2e/b4/a82eb490-f30a-a321-461a-0383c88fec95/15UMGIM23316.rgb.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/77/68/1f/77681ffc-56e6-813c-e1bc-d94a9b5893c1/mzaf_570579359857462588.plus.aac.p.m4a", collectionId: 1440838039),
        Track(id: 1781353929, title: "Not Like Us", artist: "Kendrick Lamar", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/31/3a/3f/313a3fbc-bb8f-80c7-b5a2-e226869a38cd/24UMGIM51924.rgb.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/2d/e0/e8/2de0e874-cd0b-e9a9-e876-76be13a86662/mzaf_12385336780649591409.plus.aac.p.m4a", collectionId: 1781353928),
        Track(id: 1739659142, title: "BIRDS OF A FEATHER", artist: "Billie Eilish", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/92/9f/69/929f69f1-9977-3a44-d674-11f70c852d1b/24UMGIM36186.rgb.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/34/31/d3/3431d34e-847f-5d66-df83-0bce688d997e/mzaf_18106743962423782018.plus.aac.p.m4a", collectionId: 1739659134),
        Track(id: 1762679426, title: "360", artist: "Charli xcx", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/7e/d5/09/7ed50926-eadd-40a8-cf87-85c17f212bb4/075679634283.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/6a/b2/36/6ab236ac-6b8e-60e4-aa77-8e73c7127ebc/mzaf_17637473173165118705.plus.aac.p.m4a", collectionId: 1762679425),
        Track(id: 1697335814, title: "My Love Mine All Mine", artist: "Mitski", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/8f/4b/40/8f4b4044-d02b-dc25-7d01-7d9d225fdce4/40240.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/c2/34/c5/c234c570-f1e9-79ee-4a97-984d9b3d05e9/mzaf_7768258949435817566.plus.aac.p.m4a", collectionId: 1697335341),
        Track(id: 1109715168, title: "Weird Fishes / Arpeggi", artist: "Radiohead", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/dd/50/c7/dd50c790-99ac-d3d0-5ab8-e3891fb8fd52/634904032463.png/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/3a/12/eb/3a12ebaf-89c1-1ac9-6821-3a1de510ef51/mzaf_14543910941982290973.plus.aac.p.m4a", collectionId: 1109714933),
        Track(id: 1429663163, title: "Green Light", artist: "Lorde", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/8d/0d/15/8d0d1532-493b-52ec-6a29-a239ced6931b/17UMGIM81023.rgb.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/52/98/aa/5298aa77-f5d0-e6b7-7f24-5d06409abfc8/mzaf_4826261660034311199.plus.aac.p.m4a", collectionId: 1429662346),
        Track(id: 1499378607, title: "Blinding Lights", artist: "The Weeknd", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/6f/bc/e6/6fbce6c4-c38c-72d8-4fd0-66cfff32f679/20UMGIM12176.rgb.jpg/100x100bb.jpg", previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/19/d6/60/19d660ff-e3a9-8377-15a3-ce4b28e89cac/mzaf_18422426156481158187.plus.aac.p.m4a", collectionId: 1499378108),
    ]

    static let albums: [Album] = [
        Album(id: 1440871877, title: "To Pimp a Butterfly", artist: "Kendrick Lamar", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/b5/a6/91/b5a69171-5232-3d5b-9c15-8963802f83dd/15UMGIM15814.rgb.jpg/100x100bb.jpg"),
        Album(id: 1109714933, title: "In Rainbows", artist: "Radiohead", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/dd/50/c7/dd50c790-99ac-d3d0-5ab8-e3891fb8fd52/634904032463.png/100x100bb.jpg"),
        Album(id: 1658650093, title: "SOS", artist: "SZA", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/62/93/13/6293132e-20ff-67ab-3d1f-96bb6797a6ba/196589564955.jpg/100x100bb.jpg"),
        Album(id: 1428764777, title: "Melodrama", artist: "Lorde", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/58/11/b1/5811b172-e180-25a6-69e6-4385fbbfb5dc/17UM1IM02207.rgb.jpg/100x100bb.jpg"),
        Album(id: 1146195596, title: "Blonde", artist: "Frank Ocean", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/bb/45/68/bb4568f3-68cd-619d-fbcb-4e179916545d/BlondCover-Final.jpg/100x100bb.jpg"),
        Album(id: 1463409338, title: "IGOR", artist: "Tyler, The Creator", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/0c/06/05/0c060581-6242-6a2a-a677-20170f2cf8da/886447710180.jpg/100x100bb.jpg"),
        Album(id: 1739079974, title: "BRAT", artist: "Charli xcx", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/88/4e/63/884e6321-ad41-aab1-f6f0-20efcafcfd55/075679666130.jpg/100x100bb.jpg"),
        Album(id: 1440838039, title: "Currents", artist: "Tame Impala", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/a8/2e/b4/a82eb490-f30a-a321-461a-0383c88fec95/15UMGIM23316.rgb.jpg/100x100bb.jpg"),
    ]

    static var tracksById: [Int64: Track] { Dictionary(uniqueKeysWithValues: tracks.map { (Int64($0.id), $0) }) }
    static var albumsById: [Int64: Album] { Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) }) }

    /// What the people you follow logged — the home feed.
    static let feed: [Review] = [
        review(10, by: 2, track: 0, rating: 9, vibe: "#FF2D55", "The bridge alone. I've had it on repeat all week.", hoursAgo: 2),
        review(11, by: 3, track: 2, rating: 10, vibe: "#5856D6", "Seven minutes and not one of them wasted.", hoursAgo: 5),
        review(12, by: 4, track: 4, rating: 8, vibe: "#5AC8FA", "Soft, warm, a little heartbreaking.", hoursAgo: 9),
        review(13, by: 5, track: 3, rating: 9, vibe: "#FF3B30", "Pure energy from the first second.", hoursAgo: 20),
        review(14, by: 6, track: 6, rating: 10, vibe: "#5856D6", nil, hoursAgo: 26),
        review(15, by: 2, track: 7, rating: 10, vibe: "#007AFF", "Sounds like falling into deep water.", hoursAgo: 40),
        review(16, by: 3, track: 5, rating: 8, vibe: "#4CD964", "Summer in three minutes.", hoursAgo: 52),
        review(17, by: 4, track: 8, rating: 9, vibe: "#FF9500", nil, hoursAgo: 70),
    ]

    /// The signed-in user's own song logs.
    static let myReviews: [Review] = [
        review(30, by: 1, track: 1, rating: 10, vibe: "#5AC8FA", "Every time.", hoursAgo: 4),
        review(31, by: 1, track: 7, rating: 10, vibe: "#007AFF", nil, hoursAgo: 30),
        review(32, by: 1, track: 0, rating: 9, vibe: "#FF2D55", nil, hoursAgo: 50),
        review(33, by: 1, track: 2, rating: 9, vibe: "#5856D6", nil, hoursAgo: 80),
        review(34, by: 1, track: 9, rating: 8, vibe: "#FF3B30", nil, hoursAgo: 120),
        review(35, by: 1, track: 6, rating: 9, vibe: "#5856D6", nil, hoursAgo: 150),
    ]

    static let myAlbumReviews: [AlbumReview] = albums.enumerated().map { index, album in
        AlbumReview(id: uuid(50 + index), userId: me.id, itunesCollectionId: album.id,
                    rating: [10, 10, 9, 9, 8, 9, 10, 8][index % 8],
                    reviewText: nil,
                    vibeColor: ["#5AC8FA", "#FF9500", "#007AFF", "#FF2D55", "#5856D6", "#4CD964", "#FF9500", "#4CD964"][index % 8],
                    createdAt: Date().addingTimeInterval(-Double(index) * 86_400 * 6))
    }

    /// A lifetime of logs for the "All Time" card: 128 entries, mostly passionate and dreamy.
    static let summary: SupabaseManager.UserLogSummary = {
        let vibes = ["#FF2D55", "#FF2D55", "#5856D6", "#FF2D55", "#5856D6", "#5AC8FA", "#007AFF",
                     "#FF9500", "#5856D6", "#FF2D55", "#4CD964", "#FFCC00", "#5AC8FA"]
        let ratings = [8, 9, 10, 8, 7, 9, 8, 10, 6, 9, 8, 7, 9, 10, 8, 5]
        let entries = (0..<128).map { i in
            SupabaseManager.UserLogSummary.Entry(
                vibeColor: vibes[i % vibes.count],
                rating: ratings[i % ratings.count],
                createdAt: Date().addingTimeInterval(-Double(i) * 86_400 * 3)
            )
        }
        return SupabaseManager.UserLogSummary(entries: entries)
    }()

    static let totals = (songs: 96, albums: 24, artists: 8)
    static let followers: [Profile] = (0..<48).map { Profile(id: uuid(1000 + $0), username: "f\($0)", avatarUrl: nil, bio: nil) }
    static let following: [Profile] = (0..<37).map { Profile(id: uuid(2000 + $0), username: "g\($0)", avatarUrl: nil, bio: nil) }

    static var likes: [UUID: LikeState] {
        Dictionary(uniqueKeysWithValues: feed.enumerated().map { index, review in
            (review.id, LikeState(count: [12, 7, 4, 21, 3, 9, 5, 2][index % 8], likedByMe: index % 3 == 0))
        })
    }

    static var activity: [ActivityItem] {
        let now = Date()
        func log(_ review: Review, _ type: ActivityType = .trackReview) -> ActivityItem {
            let user = profilesById[review.userId]
            return ActivityItem(id: UUID(), type: type, actorId: review.userId, actorUsername: user?.username,
                                actorAvatarUrl: nil, targetId: String(review.itunesTrackId),
                                targetName: tracksById[review.itunesTrackId]?.title, rating: review.rating,
                                vibeColor: review.vibeColor, reviewText: review.reviewText, createdAt: review.createdAt)
        }
        func follow(_ id: Int, hoursAgo: Double) -> ActivityItem {
            ActivityItem(id: UUID(), type: .newFollower, actorId: uuid(id), actorUsername: profilesById[uuid(id)]?.username,
                         actorAvatarUrl: nil, targetId: nil, targetName: nil, rating: nil, vibeColor: nil,
                         reviewText: nil, createdAt: now.addingTimeInterval(-hoursAgo * 3600))
        }
        return [log(feed[0]), follow(5, hoursAgo: 4), log(feed[1]), log(feed[2]), follow(6, hoursAgo: 30), log(feed[5])]
    }

    private static func review(_ n: Int, by user: Int, track: Int, rating: Int, vibe: String,
                               _ text: String?, hoursAgo: Double) -> Review {
        Review(id: uuid(n), userId: uuid(user), itunesTrackId: Int64(tracks[track].id), spotifyTrackId: nil,
               rating: rating, reviewText: text, vibeColor: vibe,
               createdAt: Date().addingTimeInterval(-hoursAgo * 3600))
    }

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }
}
#endif
