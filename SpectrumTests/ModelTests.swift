import Foundation
import Testing
@testable import Spectrum

/// Ordering, aggregation and link-building — the pure logic the UI reads straight out.
@MainActor
struct ModelTests {

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: iso)!
    }

    private func album(_ title: String, _ released: String?) -> Album {
        Album(
            id: Int64(abs(title.hashValue % 100_000)),
            title: title,
            artist: "Test",
            artworkUrl100: "https://example.com/100x100.jpg",
            releaseDate: released.map(date)
        )
    }

    // MARK: - Album.newestFirst

    @Test func albumsSortNewestFirst() {
        let sorted = [
            album("Old", "2010-01-01"),
            album("New", "2024-01-01"),
            album("Middle", "2018-01-01")
        ].sorted(by: Album.newestFirst).map(\.title)

        #expect(sorted == ["New", "Middle", "Old"])
    }

    @Test func undatedAlbumsSortLast() {
        let sorted = [
            album("Undated", nil),
            album("Dated", "2010-01-01")
        ].sorted(by: Album.newestFirst).map(\.title)

        #expect(sorted == ["Dated", "Undated"])
    }

    /// Deluxe editions ship on the same day as the standard one. Without the title tie-break
    /// the two swap places between loads of the same data.
    @Test func sameDayReleasesAreOrderedByTitle() {
        let sorted = [
            album("Zebra", "2020-05-01"),
            album("Apple", "2020-05-01")
        ].sorted(by: Album.newestFirst).map(\.title)

        #expect(sorted == ["Apple", "Zebra"])
    }

    @Test func undatedAlbumsAreOrderedByTitleAmongThemselves() {
        let sorted = [
            album("Zebra", nil),
            album("Apple", nil)
        ].sorted(by: Album.newestFirst).map(\.title)

        #expect(sorted == ["Apple", "Zebra"])
    }

    // MARK: - CommunityStats

    /// Ratings are stored 0...10 and displayed 0...5.
    @Test func averageRatingIsHalfTheStoredValue() {
        let stats = CommunityStats(ratings: [10, 8, 6], vibeHexes: [])
        #expect(abs(stats.averageRating - 4.0) < 0.0001)
        #expect(stats.count == 3)
    }

    @Test func emptyStatsDoNotDivideByZero() {
        let stats = CommunityStats.empty
        #expect(stats.isEmpty)
        #expect(stats.averageRating == 0)
        #expect(stats.topVibe == nil)
    }

    @Test func vibeSharesAreOrderedByPopularity() {
        let stats = CommunityStats(
            ratings: [8, 8, 8],
            vibeHexes: ["#5AC8FA", "#5AC8FA", "#FF3B30"]
        )
        #expect(stats.topVibe?.hex == "#5AC8FA")
        #expect(stats.topVibe?.count == 2)
        #expect(abs((stats.topVibe?.share ?? 0) - 2.0 / 3.0) < 0.0001)
    }

    /// Equal counts must not flicker between loads, so ties fall back to the hex.
    @Test func tiedVibesAreOrderedDeterministically() {
        let hexes = ["#FF3B30", "#5AC8FA"]
        let first = CommunityStats(ratings: [8, 8], vibeHexes: hexes).vibes.map(\.hex)
        let second = CommunityStats(ratings: [8, 8], vibeHexes: hexes.reversed()).vibes.map(\.hex)
        #expect(first == second)
    }

    // MARK: - VibePalette

    @Test func paletteEntriesSnapToThemselves() {
        for hex in VibePalette.colors {
            #expect(VibePalette.snap(hex) == hex)
        }
    }

    @Test func lowercasePaletteEntriesStillSnapExactly() {
        #expect(VibePalette.snap("#ff3b30") == "#FF3B30")
    }

    /// Artist ratings save an artwork-derived hex that is almost never a palette entry.
    @Test func nearbyColoursSnapToTheClosestPaletteEntry() {
        #expect(VibePalette.snap("#FF3B31") == "#FF3B30")
        #expect(VibePalette.snap("#4CD965") == "#4CD964")
    }

    @Test func everyPaletteEntryHasAName() {
        for hex in VibePalette.colors {
            #expect(VibePalette.label(for: hex) != "Vibe")
        }
    }

    // MARK: - Track.appleMusicLink

    private func track(appleMusicUrl: String?) -> Track {
        Track(
            id: 1440857781,
            title: "Test",
            artist: "Test",
            artworkUrl100: "https://example.com/100x100.jpg",
            previewUrl: nil,
            appleMusicUrl: appleMusicUrl
        )
    }

    @Test func shareLinkPrefersTheCanonicalMusicKitURL() {
        let url = track(appleMusicUrl: "https://music.apple.com/us/album/x/1/i=2").appleMusicLink
        #expect(url?.absoluteString == "https://music.apple.com/us/album/x/1/i=2")
    }

    /// Tracks rebuilt from a stored id (feed cards, profile logs) carry no MusicKit URL.
    /// The fallback still has to be an https link — the old share used a `spotify:` scheme,
    /// which is not tappable in Messages and dies without Spotify installed.
    @Test func shareLinkFallsBackToAnHTTPSAppleMusicURL() {
        let url = track(appleMusicUrl: nil).appleMusicLink
        #expect(url?.scheme == "https")
        #expect(url?.host == "music.apple.com")
        #expect(url?.absoluteString == "https://music.apple.com/song/1440857781")
    }

    @Test func shareLinkFallsBackWhenTheStoredURLIsUnusable() {
        #expect(track(appleMusicUrl: "").appleMusicLink?.host == "music.apple.com")
    }
}

/// The optimistic toggle the feed and the log page both apply before the network answers.
@MainActor
struct LikeStateTests {

    @Test func likingIncrementsAndMarks() {
        let next = LikeState(count: 4, likedByMe: false).toggled()
        #expect(next.count == 5)
        #expect(next.likedByMe)
    }

    @Test func unlikingDecrementsAndUnmarks() {
        let next = LikeState(count: 4, likedByMe: true).toggled()
        #expect(next.count == 3)
        #expect(next.likedByMe == false)
    }

    /// The count can lag behind reality — another viewer's unlike arrives between the page
    /// load and the tap. Going negative would render "-1 likes".
    @Test func unlikingCannotDriveTheCountBelowZero() {
        let next = LikeState(count: 0, likedByMe: true).toggled()
        #expect(next.count == 0)
        #expect(next.likedByMe == false)
    }

    /// Reverting a failed write has to land exactly back on the original state.
    @Test func togglingTwiceReturnsToTheStartingState() {
        let start = LikeState(count: 7, likedByMe: false)
        #expect(start.toggled().toggled() == start)
    }
}

/// Catalog metadata that now rides along on requests the app was already making.
@MainActor
struct CatalogMetadataTests {

    private func album(explicit: Bool?, badges: [AudioBadge] = [], label: String? = nil) -> Album {
        Album(
            id: 1,
            title: "Test",
            artist: "Test",
            artworkUrl100: "https://example.com/100x100.jpg",
            isExplicit: explicit,
            audioBadges: badges,
            recordLabel: label
        )
    }

    /// `nil` means "the catalog didn't say", which is not the same as "clean" — the badge row
    /// has to stay silent rather than assert either way.
    @Test func unknownExplicitIsNotTreatedAsExplicit() {
        #expect(album(explicit: nil).isExplicit == nil)
    }

    @Test func badgesSurviveOnTheModel() {
        let record = album(explicit: true, badges: [.dolbyAtmos, .lossless], label: "Columbia")
        #expect(record.isExplicit == true)
        #expect(record.audioBadges == [.dolbyAtmos, .lossless])
        #expect(record.recordLabel == "Columbia")
    }

    /// Decoding from stored JSON can't know any of this — only a MusicKit request carries it.
    /// The point of the test is that the decoder doesn't invent a value.
    @Test func decodedAlbumsHaveNoCatalogMetadata() throws {
        let json = """
        {"collectionId": 1, "collectionName": "T", "artistName": "A", "artworkUrl100": "u"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Album.self, from: json)
        #expect(decoded.isExplicit == nil)
        #expect(decoded.audioBadges.isEmpty)
        #expect(decoded.recordLabel == nil)
    }

    @Test func everyAudioBadgeHasALabelAndAnIcon() {
        for badge in AudioBadge.allCases {
            #expect(!badge.label.isEmpty)
            #expect(!badge.icon.isEmpty)
        }
    }
}
