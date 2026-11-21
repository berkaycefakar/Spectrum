import SwiftUI

/// Thresholds for "Highest rated on Spectrum". On from day one: any rated item can rank, and
/// the Bayesian average in the RPC keeps a lone 5★ from topping 20 ratings of 4.6. Raise
/// `minRatingsPerItem` as the community grows; no migration needed.
enum TopRated {
    /// Ratings an item needs before it can rank.
    static let minRatingsPerItem = 1
    /// Ranked items needed before a tab appears.
    static let minItemsToShow = 1
}

/// "Highest rated on Spectrum": songs, albums and artists ranked by the community.
struct TopRatedSection: View {
    @State private var kind: SupabaseManager.TopRatedKind = .albums
    @State private var rows: [SupabaseManager.TopRatedKind: [SupabaseManager.TopRatedRow]] = [:]
    @State private var tracks: [Int64: Track] = [:]
    @State private var albums: [Int64: Album] = [:]

    /// Kinds that have enough data to show.
    private var availableKinds: [SupabaseManager.TopRatedKind] {
        SupabaseManager.TopRatedKind.allCases.filter { (rows[$0]?.count ?? 0) >= TopRated.minItemsToShow }
    }

    var body: some View {
        // A VStack, not a Group: an empty Group is no view at all, so its `.task` never ran
        // and the section could never load its way out of being empty.
        VStack(spacing: 0) {
            if !availableKinds.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Highest Rated on Spectrum", bundle: appStringsBundle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)

                    if availableKinds.count > 1 {
                        Picker("", selection: $kind) {
                            ForEach(availableKinds) { k in Text(title(k)).tag(k) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(Array((rows[shownKind] ?? []).prefix(10).enumerated()), id: \.offset) { index, row in
                            rowView(rank: index + 1, row: row)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task { await load() }
    }

    private var shownKind: SupabaseManager.TopRatedKind {
        availableKinds.contains(kind) ? kind : (availableKinds.first ?? .albums)
    }

    private func title(_ k: SupabaseManager.TopRatedKind) -> String {
        switch k {
        case .songs: String(localized: "Songs", bundle: appStringsBundle)
        case .albums: String(localized: "Albums", bundle: appStringsBundle)
        case .artists: String(localized: "Artists", bundle: appStringsBundle)
        }
    }

    @ViewBuilder
    private func rowView(rank: Int, row: SupabaseManager.TopRatedRow) -> some View {
        switch shownKind {
        case .songs:
            if let id = row.itemId, let track = tracks[id] {
                NavigationLink(value: AppRoute.track(track)) {
                    line(rank: rank, art: track.artworkUrl600, title: track.title, subtitle: track.artist, row: row)
                }
                .buttonStyle(.plain)
            }
        case .albums:
            if let id = row.itemId, let album = albums[id] {
                NavigationLink(value: AppRoute.album(album)) {
                    line(rank: rank, art: album.artworkUrl600, title: album.title, subtitle: album.artist, row: row)
                }
                .buttonStyle(.plain)
            }
        case .artists:
            if let name = row.artistName {
                NavigationLink(value: AppRoute.artist(name: name, id: nil)) {
                    line(rank: rank, art: nil, title: name, subtitle: nil, row: row)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func line(rank: Int, art: URL?, title: String, subtitle: String?, row: SupabaseManager.TopRatedRow) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 22, alignment: .trailing)
            Group {
                if let art {
                    AsyncImage(url: art) { phase in
                        (phase.image?.resizable() ?? Image(systemName: "music.note").resizable())
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Circle().fill(.white.opacity(0.08))
                        .overlay(Text(String(title.prefix(1))).font(.headline).foregroundStyle(.white))
                }
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text(String(format: "%.1f", row.avgRating / 2)).font(.subheadline.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(Color.spectrumAccent)
                Text(row.ratingCount == 1 ? "1 rating" : "\(row.ratingCount) ratings", bundle: appStringsBundle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        // Missing RPCs (migration not applied) just leave the section hidden.
        async let songs = try? SupabaseManager.shared.topRated(.songs, minRatings: TopRated.minRatingsPerItem)
        async let albumRows = try? SupabaseManager.shared.topRated(.albums, minRatings: TopRated.minRatingsPerItem)
        async let artists = try? SupabaseManager.shared.topRated(.artists, minRatings: TopRated.minRatingsPerItem)
        let s = await songs ?? [], a = await albumRows ?? [], r = await artists ?? []

        let trackIds = s.compactMap(\.itemId), albumIds = a.compactMap(\.itemId)
        async let t = trackIds.isEmpty ? [:] : MusicService.shared.fetchTracks(ids: trackIds)
        async let al = albumIds.isEmpty ? [:] : MusicService.shared.fetchAlbums(ids: albumIds)
        tracks = await t
        albums = await al
        rows = [.songs: s.filter { $0.itemId.map { tracks[$0] != nil } ?? false },
                .albums: a.filter { $0.itemId.map { albums[$0] != nil } ?? false },
                .artists: r]
    }
}
