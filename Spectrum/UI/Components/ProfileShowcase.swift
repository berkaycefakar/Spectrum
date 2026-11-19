import SwiftUI

// The top of the profile: a cover banner, the favourite-four shelf and an all-time summary.
// Shared by the user's own profile and other people's, so everything owner-only is optional.

// MARK: - Cover Header

struct ProfileCoverHeader: View {
    let profile: Profile
    /// Album art for the banner. Nil draws the banner from `vibeHexes` instead.
    let coverAlbum: Album?
    /// The user's most-logged vibes, most frequent first.
    let vibeHexes: [String]
    let followersCount: Int
    let followingCount: Int
    var onChangeCover: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onSettings: (() -> Void)? = nil
    var onFollowersTapped: () -> Void = {}
    var onFollowingTapped: () -> Void = {}

    @ObservedObject private var premium = PremiumStore.shared

    private let bannerHeight: CGFloat = 210
    private let avatarSize: CGFloat = 92

    var body: some View {
        VStack(spacing: 0) {
            banner
                .frame(height: bannerHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    // Fades the art into the page so the avatar and name sit on black.
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }
                .overlay(alignment: .topTrailing) { bannerButtons }

            VStack(spacing: 14) {
                avatar
                    .padding(.top, -avatarSize / 2)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(profile.username ?? String(localized: "Anonymous", bundle: appStringsBundle))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        // Own profile only until the subscription is mirrored to Supabase
                        // (docs/PREMIUM_PLAN.md, step 3).
                        if PremiumStore.isOfferEnabled, onEdit != nil, premium.isPlus {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.spectrumAccent)
                                .accessibilityLabel("Spectrum+")
                        }
                    }

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 22) {
                    Button(action: onFollowersTapped) {
                        countLabel(followersCount, String(localized: "Followers", bundle: appStringsBundle))
                    }
                    Button(action: onFollowingTapped) {
                        countLabel(followingCount, String(localized: "Following", bundle: appStringsBundle))
                    }
                }
                .buttonStyle(.plain)

                if let onEdit {
                    Button(action: onEdit) {
                        Text("Edit Profile")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 38)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let url = coverAlbum?.artworkUrl600 {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    vibeBands
                }
            }
        } else {
            vibeBands
        }
    }

    private var vibeBands: some View { VibeBands(hexes: vibeHexes) }

    private var bannerButtons: some View {
        HStack(spacing: 8) {
            if let onChangeCover {
                Button(action: onChangeCover) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Change Cover")
            }
            if let onSettings {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Settings")
            }
        }
        // Clears the status bar; the banner itself runs under it.
        .padding(.top, 58)
        .padding(.trailing, 16)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color(hex: vibeHexes.first ?? "#FF8A3D").opacity(0.35))
            if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        initial
                    }
                }
            } else {
                initial
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(.black, lineWidth: 4))
    }

    private var initial: some View {
        Text(String((profile.username ?? "?").prefix(1)).uppercased())
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }

    private func countLabel(_ value: Int, _ label: String) -> some View {
        (Text("\(value) ").fontWeight(.bold).foregroundColor(.white)
         + Text(label).foregroundColor(.white.opacity(0.55)))
            .font(.subheadline)
    }
}

// MARK: - Favourite Four Shelf

struct FavoriteShelf: View {
    /// In shelf order; fewer than four leaves empty slots.
    let albums: [Album]
    /// Owners get a tappable edit affordance and "+" slots; visitors see only what's there.
    var onEdit: (() -> Void)? = nil

    var body: some View {
        if albums.isEmpty && onEdit == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Favorite Four")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.spectrumAccent)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    ForEach(0..<4, id: \.self) { index in
                        slot(index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func slot(_ index: Int) -> some View {
        if index < albums.count {
            let album = albums[index]
            NavigationLink(value: AppRoute.album(album)) {
                VStack(alignment: .leading, spacing: 6) {
                    // Square slot first, image filled into it: an `aspectRatio(.fit)` on the
                    // image itself let wide artwork shrink its slot out of line with the others.
                    Color.white.opacity(0.06)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            AsyncImage(url: album.artworkUrl600) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(album.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(album.artist)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(album.title), \(album.artist)")
        } else {
            Button { onEdit?() } label: {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(onEdit == nil ? 0 : 0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(onEdit == nil)
            .accessibilityLabel("Add a favorite album")
        }
    }
}

// MARK: - All-Time Summary

/// Lifetime numbers, the lifetime spectrum and how the user's ratings are spread.
struct AllTimeSummaryCard: View {
    let summary: SupabaseManager.UserLogSummary
    let totalLogs: Int
    var onTap: (() -> Void)? = nil

    private var vibeShares: [(hex: String, share: Double)] {
        let total = Double(summary.vibeColors.count)
        guard total > 0 else { return [] }
        let counts = Dictionary(grouping: summary.vibeColors.map { VibePalette.snap($0) }, by: { $0 })
            .mapValues { Double($0.count) }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { (hex: $0.key, share: $0.value / total) }
    }

    /// Ten buckets for the stored 1...10 (half-star) ratings.
    private var ratingBuckets: [Int] {
        var buckets = Array(repeating: 0, count: 10)
        for r in summary.ratings where (1...10).contains(r) { buckets[r - 1] += 1 }
        return buckets
    }

    private var since: String? {
        guard let first = summary.entries.map(\.createdAt).min() else { return nil }
        return first.formatted(.dateTime.month(.abbreviated).year())
    }

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("All Time")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if onTap != nil {
                        HStack(spacing: 3) {
                            Text("See all").font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.spectrumAccent)
                    }
                }

                HStack(alignment: .top, spacing: 0) {
                    stat("\(totalLogs)", String(localized: "Logs", bundle: appStringsBundle))
                    stat(summary.entries.isEmpty ? "–" : String(format: "%.1f", summary.averageRating),
                         String(localized: "Avg Rating", bundle: appStringsBundle))
                    stat(since ?? "–", String(localized: "Since", bundle: appStringsBundle))
                }

                if !vibeShares.isEmpty {
                    spectrumBar
                    histogram
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spectrumBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(vibeShares, id: \.hex) { item in
                        Color(hex: item.hex)
                            .frame(width: max(3, (geo.size.width - CGFloat(vibeShares.count - 1) * 2) * item.share))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())

            // Top four named; colour alone can't carry the meaning.
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 6) {
                ForEach(vibeShares.prefix(4), id: \.hex) { item in
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: item.hex)).frame(width: 8, height: 8)
                        Text("\(VibePalette.label(for: item.hex)) \(Int((item.share * 100).rounded()))%")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var histogram: some View {
        let buckets = ratingBuckets
        let peak = max(buckets.max() ?? 1, 1)
        let peakIndex = buckets.firstIndex(of: buckets.max() ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Ratings")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == peakIndex ? Color.spectrumAccent : .white.opacity(0.22))
                        .frame(height: max(3, 48 * CGFloat(buckets[i]) / CGFloat(peak)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 48, alignment: .bottom)
            HStack {
                Image(systemName: "star.fill").font(.system(size: 9))
                Text("0.5")
                Spacer()
                Text("5")
                Image(systemName: "star.fill").font(.system(size: 9))
            }
            .font(.caption2)
            .foregroundStyle(Color(hex: "#FFCC00").opacity(0.8))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating distribution")
    }
}

// MARK: - Favourites Editor

/// Picks the favourite four — from albums the user has rated, or from a catalog search.
struct FavoritesEditorSheet: View {
    /// Albums the user has rated, best first; shown when the search field is empty.
    let ratedAlbums: [Album]
    let initial: [Album]
    let onSave: ([Album]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: [Album] = []
    @State private var query = ""
    @State private var results: [Album] = []
    /// Ids last written, so closing the sheet only saves when something actually changed.
    @State private var savedIds: [Int64] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        pickedRow
                        LazyVStack(spacing: 8) {
                            ForEach(query.isEmpty ? ratedAlbums : results) { album in
                                row(album)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Favorite Four")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Search albums"))
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty else { results = []; return }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = (try? await MusicService.shared.searchAlbums(query: q)) ?? []
            }
            // Every change saves itself; there's no Save button to miss. The short pause
            // folds a quick run of taps into one write.
            .task(id: picked.map(\.id)) {
                let ids = picked.map(\.id)
                guard ids != savedIds else { return }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                savedIds = ids
                await onSave(picked)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel(Text("Done", bundle: appStringsBundle))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .onAppear {
            picked = initial
            savedIds = initial.map(\.id)
        }
        // Closing inside the pause would cancel the pending write; finish it here instead.
        .onDisappear {
            let final = picked
            guard final.map(\.id) != savedIds else { return }
            Task { await onSave(final) }
        }
    }

    private var pickedRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { i in
                if i < picked.count {
                    AsyncImage(url: picked[i].artworkUrl600) { phase in
                        (phase.image?.resizable() ?? Image(systemName: "music.note").resizable())
                            .aspectRatio(contentMode: .fill)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        Button { picked.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .padding(4)
                        .accessibilityLabel("Remove \(picked[i].title)")
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func row(_ album: Album) -> some View {
        let isPicked = picked.contains { $0.id == album.id }
        return Button {
            if let idx = picked.firstIndex(where: { $0.id == album.id }) {
                picked.remove(at: idx)
            } else if picked.count < 4 {
                picked.append(album)
            }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: album.artworkUrl600) { phase in
                    (phase.image?.resizable() ?? Image(systemName: "music.note").resizable())
                        .aspectRatio(contentMode: .fill)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(album.artist).font(.caption).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer()
                Image(systemName: isPicked ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isPicked ? Color.spectrumAccent : .white.opacity(picked.count < 4 ? 0.5 : 0.15))
            }
            .padding(10)
            .background(.white.opacity(isPicked ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Vibe bands

/// The user's spectrum as soft overlapping glows: the banner before they pick an album, and
/// the "spectrum" tile in the cover picker.
struct VibeBands: View {
    let hexes: [String]

    var body: some View {
        let shown = hexes.isEmpty ? ["#5856D6", "#FF2D55", "#FF9500"] : Array(hexes.prefix(4))
        GeometryReader { geo in
            ZStack {
                Color(hex: "#0E0A14")
                ForEach(Array(shown.enumerated()), id: \.offset) { index, hex in
                    let step = geo.size.width / CGFloat(max(shown.count, 1))
                    Circle()
                        .fill(Color(hex: hex).opacity(index == 0 ? 0.85 : 0.65))
                        .frame(width: geo.size.width * 0.62, height: geo.size.width * 0.62)
                        .position(x: step * (CGFloat(index) + 0.5),
                                  y: geo.size.height * (index.isMultiple(of: 2) ? 0.35 : 0.6))
                        .blur(radius: geo.size.width * 0.12)
                }
            }
        }
    }
}

// MARK: - Cover Picker

/// Picks the profile banner: the user's spectrum, or one of their favourite four. Each choice
/// is shown as it will look; tapping one saves it and closes the sheet.
struct CoverPickerSheet: View {
    let favorites: [Album]
    let currentAlbumId: Int64?
    let vibeHexes: [String]
    let onPick: (Int64?) async -> Void
    let onEditFavorites: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving: Int64?? = nil

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    tile(id: nil, label: String(localized: "Your spectrum", bundle: appStringsBundle)) { VibeBands(hexes: vibeHexes) }
                    ForEach(favorites) { album in
                        tile(id: album.id, label: album.title) {
                            AsyncImage(url: album.artworkUrl600) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.white.opacity(0.06)
                                }
                            }
                        }
                    }
                    if favorites.count < 4 {
                        Button {
                            dismiss()
                            onEditFavorites()
                        } label: {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .aspectRatio(1.6, contentMode: .fit)
                                .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.white.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Add favorite albums", bundle: appStringsBundle))
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(Text("Cover", bundle: appStringsBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("Close", bundle: appStringsBundle))
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func tile<Content: View>(id: Int64?, label: String, @ViewBuilder content: () -> Content) -> some View {
        let isCurrent = id == currentAlbumId
        return Button {
            guard saving == nil else { return }
            saving = .some(id)
            Task {
                await onPick(id)
                dismiss()
            }
        } label: {
            // A fixed-ratio frame the content fills, so every tile is the same size whatever
            // the artwork's own shape.
            Color.clear
                .aspectRatio(1.6, contentMode: .fit)
                .overlay { content() }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isCurrent ? Color.spectrumAccent : .white.opacity(0.08), lineWidth: isCurrent ? 2.5 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white, Color.spectrumAccent)
                            .padding(8)
                    } else if saving == .some(id) {
                        ProgressView().tint(.white).padding(8)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
