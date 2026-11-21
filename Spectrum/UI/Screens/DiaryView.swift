import SwiftUI

/// Every song and album someone logged, newest first and grouped by month, the way
/// Letterboxd's diary reads: the day on the left, then the record, its stars and whether
/// there's a written review.
struct DiaryView: View {
    let userId: UUID
    let isOwner: Bool

    private enum Item: Identifiable {
        case song(Review)
        case album(AlbumReview)

        var id: UUID {
            switch self {
            case .song(let r): r.id
            case .album(let r): r.id
            }
        }
        var date: Date {
            switch self {
            case .song(let r): r.createdAt
            case .album(let r): r.createdAt
            }
        }
        var rating: Int {
            switch self {
            case .song(let r): r.rating
            case .album(let r): r.rating
            }
        }
        var vibe: String {
            switch self {
            case .song(let r): r.vibeColor
            case .album(let r): r.vibeColor
            }
        }
        var hasText: Bool {
            switch self {
            case .song(let r): !(r.reviewText ?? "").isEmpty
            case .album(let r): !(r.reviewText ?? "").isEmpty
            }
        }
    }

    @State private var songs: [Review] = []
    @State private var albumLogs: [AlbumReview] = []
    @State private var tracks: [Int64: Track] = [:]
    @State private var albums: [Int64: Album] = [:]
    @State private var songsDone = false
    @State private var albumsDone = false
    @State private var isLoading = true

    /// Both lists arrive newest first in pages. Merged, an entry is only safe to show once
    /// it's newer than the oldest row loaded from a list that still has more: anything
    /// older could still be followed by an unloaded row from the other list.
    private var shown: [Item] {
        var cutoff = Date.distantPast
        if !songsDone, let last = songs.last { cutoff = max(cutoff, last.createdAt) }
        if !albumsDone, let last = albumLogs.last { cutoff = max(cutoff, last.createdAt) }
        let all = songs.map(Item.song) + albumLogs.map(Item.album)
        return all.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
    }

    private var months: [(key: Date, items: [Item])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: shown) {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) ?? $0.date
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 60)
                    } else if shown.isEmpty {
                        Text(isOwner ? "Nothing logged yet. Your logs show up here by date."
                                     : "Nothing logged yet.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                    ForEach(months, id: \.key) { month in
                        Section {
                            ForEach(month.items) { item in
                                row(item)
                                Divider().overlay(.white.opacity(0.06)).padding(.leading, 62)
                            }
                        } header: {
                            Text(month.key.formatted(.dateTime.month(.wide).year()))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(.black.opacity(0.92))
                        }
                    }
                    if !isLoading && !(songsDone && albumsDone) {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .task(id: songs.count + albumLogs.count) { await loadMore() }
                    }
                }
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(Text("Diary", bundle: appStringsBundle))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard isLoading else { return }
            await loadMore()
            isLoading = false
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        let content = HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(item.date.formatted(.dateTime.day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(item.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(width: 38)

            AsyncImage(url: art(item)) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                else { Color.white.opacity(0.08) }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: isAlbum(item) ? 4 : 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title(item) ?? " ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle(item) ?? " ")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    StarRow(stars: Double(item.rating) / 2)
                    Circle().fill(Color(hex: item.vibe)).frame(width: 7, height: 7)
                    if item.hasText {
                        Image(systemName: "text.alignleft")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .accessibilityLabel(Text("Has a review", bundle: appStringsBundle))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())

        if let route = route(item) {
            NavigationLink { AppRouteView(route: route) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func isAlbum(_ item: Item) -> Bool {
        if case .album = item { return true }
        return false
    }

    private func art(_ item: Item) -> URL? {
        switch item {
        case .song(let r): tracks[r.itunesTrackId]?.artworkUrl600
        case .album(let r): albums[r.itunesCollectionId]?.artworkUrl600
        }
    }

    private func title(_ item: Item) -> String? {
        switch item {
        case .song(let r): tracks[r.itunesTrackId]?.title
        case .album(let r): albums[r.itunesCollectionId]?.title
        }
    }

    private func subtitle(_ item: Item) -> String? {
        switch item {
        case .song(let r): tracks[r.itunesTrackId]?.artist
        case .album(let r): albums[r.itunesCollectionId].map {
            String(localized: "Album · \($0.artist)", bundle: appStringsBundle)
        }
        }
    }

    private func route(_ item: Item) -> AppRoute? {
        switch item {
        case .song(let r): tracks[r.itunesTrackId].map { .log(track: $0, review: r, isOwner: isOwner) }
        case .album(let r): albums[r.itunesCollectionId].map { .album($0) }
        }
    }

    /// Next page of whichever list is holding the merge back (or both on the first load).
    private func loadMore() async {
        let needSongs = !songsDone && (songs.isEmpty || albumsDone
            || (songs.last?.createdAt ?? .distantPast) >= (albumLogs.last?.createdAt ?? .distantPast))
        let needAlbums = !albumsDone && (albumLogs.isEmpty || songsDone || !needSongs)
        let size = SupabaseManager.pageSize

        async let songPage: [Review] = needSongs
            ? ((try? await SupabaseManager.shared.getUserReviewsByDate(userId: userId, offset: songs.count)) ?? [])
            : []
        async let albumPage: [AlbumReview] = needAlbums
            ? ((try? await SupabaseManager.shared.getUserAlbumReviewsByDate(userId: userId, offset: albumLogs.count)) ?? [])
            : []
        let (s, a) = await (songPage, albumPage)

        async let t = s.isEmpty ? [:] : MusicService.shared.fetchTracks(ids: Array(Set(s.map(\.itunesTrackId))))
        async let al = a.isEmpty ? [:] : MusicService.shared.fetchAlbums(ids: Array(Set(a.map(\.itunesCollectionId))))
        let (newTracks, newAlbums) = await (t, al)

        tracks.merge(newTracks) { _, new in new }
        albums.merge(newAlbums) { _, new in new }
        let knownSongs = Set(songs.map(\.id)), knownAlbums = Set(albumLogs.map(\.id))
        songs += s.filter { !knownSongs.contains($0.id) }
        albumLogs += a.filter { !knownAlbums.contains($0.id) }
        if needSongs && s.count < size { songsDone = true }
        if needAlbums && a.count < size { albumsDone = true }
    }
}

/// Five small stars filled to a 0–5 score, halves included.
struct StarRow: View {
    let stars: Double
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                let d = Double(i)
                Image(systemName: stars >= d ? "star.fill" : (stars >= d - 0.5 ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .foregroundStyle(Color(hex: "#FFCC00"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(String(format: "%.1f", stars)) stars"))
    }
}

/// One logged record on a profile wall: the cover, square and small like a Letterboxd poster
/// grid, with its stars underneath. Three to a row.
struct LogCoverCell: View {
    let artworkUrl: URL?
    let title: String
    var rating: Double? = nil
    var vibeColor: Color = .clear
    var cornerRadius: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImage(url: artworkUrl) { phase in
                        if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                        else { Color.white.opacity(0.08) }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(vibeColor).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 1))
                        .padding(6)
                }
            if let rating, rating > 0 {
                StarRow(stars: rating, size: 9)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

/// "Diary": a row opening every log by date, the way Letterboxd's profile links its diary.
struct DiaryEntryRow: View {
    let userId: UUID
    let isOwner: Bool
    let count: Int

    var body: some View {
        NavigationLink {
            DiaryView(userId: userId, isOwner: isOwner)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.spectrumAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.spectrumAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Diary", bundle: appStringsBundle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Every log, by date", bundle: appStringsBundle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
