import SwiftUI

/// One list, open.
///
/// Items are stored as bare references — an Apple id, or an artist's name — so everything
/// visible here has to be resolved through MusicKit first. That happens in two batched
/// requests for the whole list rather than one per row; a twenty-record list resolving itself
/// row by row is twenty round-trips before the first artwork appears.
struct ListDetailView: View {
    let list: MusicList
    let isOwner: Bool
    var onChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var items: [MusicListItem] = []
    @State private var tracks: [Int64: Track] = [:]
    @State private var albums: [Int64: Album] = [:]
    @State private var artistBriefs: [String: ArtistBrief] = [:]
    @State private var isLoading = true
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var isEditingOrder = false
    @State private var showAddRecords = false
    @State private var currentList: MusicList

    init(list: MusicList, isOwner: Bool, onChanged: (() -> Void)? = nil) {
        self.list = list
        self.isOwner = isOwner
        self.onChanged = onChanged
        _currentList = State(initialValue: list)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if items.isEmpty {
                emptyState
            } else if isEditingOrder {
                // A plain `List` for the duration of a reorder only: `EditButton`-style drag
                // handles are the one interaction SwiftUI won't give a LazyVStack.
                reorderList
            } else {
                content
            }
        }
        .navigationTitle(currentList.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await load() }
        .sheet(isPresented: $showEdit) {
            EditListView(list: currentList) {
                Task { await reloadList() }
                onChanged?()
            }
        }
        .sheet(isPresented: $showAddRecords) {
            AddRecordsToListView(
                list: currentList,
                existing: Set(items.map(\.contentRef)),
                onAdded: {
                    Task { await load() }
                    onChanged?()
                }
            )
        }
        .alert("Delete List", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteList() }
            }
        } message: {
            Text("This deletes “\(currentList.title)” and everything in it. This can't be undone.")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isOwner {
            // Filling a list was only possible from the other end — open a song, tap "Add to
            // List" — so a list you had just made opened empty with no way forward from it.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddRecords = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Add records to this list")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    if items.count > 1 {
                        Button {
                            isEditingOrder.toggle()
                        } label: {
                            Label(
                                isEditingOrder ? "Done Reordering" : "Reorder",
                                systemImage: "arrow.up.arrow.down"
                            )
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete List", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("List options")
            }
        }
    }

    // MARK: - Content

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = currentList.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 8) {
                Text(items.count == 1 ? "1 record" : "\(items.count) records")
                if !currentList.isPublic {
                    Text("· Private")
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(for: item, rank: index + 1)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func row(for item: MusicListItem, rank: Int) -> some View {
        let card = ListItemRow(
            rank: rank,
            item: item,
            track: item.numericRef.flatMap { tracks[$0] },
            album: item.numericRef.flatMap { albums[$0] },
            brief: item.kind == .artist ? artistBriefs[item.contentRef] : nil
        )

        Group {
            // Only linkable once the catalog lookup has come back — a row whose destination
            // doesn't exist yet is a dead tap, which reads as a broken list.
            if let destination = destination(for: item) {
                NavigationLink(value: destination) { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
        // `swipeActions` was the original gesture here and never fired once: it only applies
        // to rows inside a `List`, and this is a LazyVStack in a ScrollView. Removing an item
        // was therefore impossible. A context menu works in both containers.
        .contextMenu {
            if isOwner {
                Button(role: .destructive) {
                    Task { await remove(item) }
                } label: {
                    Label("Remove from list", systemImage: "trash")
                }
            }
        }
    }

    private func destination(for item: MusicListItem) -> AppRoute? {
        switch item.kind {
        case .song:
            return item.numericRef.flatMap { tracks[$0] }.map { AppRoute.track($0) }
        case .album:
            return item.numericRef.flatMap { albums[$0] }.map { AppRoute.album($0) }
        case .artist:
            // Artists are keyed by name, so this one is always openable — the page resolves
            // itself from the name, and now has a proper failure state if it can't.
            return .artist(name: item.contentRef, id: artistBriefs[item.contentRef]?.id)
        }
    }

    private var reorderList: some View {
        List {
            ForEach(items) { item in
                ListItemRow(
                    rank: (items.firstIndex(of: item) ?? 0) + 1,
                    item: item,
                    track: item.numericRef.flatMap { tracks[$0] },
                    album: item.numericRef.flatMap { albums[$0] },
                    brief: item.kind == .artist ? artistBriefs[item.contentRef] : nil
                )
                .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                items.move(fromOffsets: source, toOffset: destination)
                Task { await persistOrder() }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("Nothing in this list yet")
                .font(.headline)
                .foregroundStyle(.white)
            if isOwner {
                Text("Search for songs, albums or artists to put in it.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    showAddRecords = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                        Text("Add records")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#FF00FF"), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        let loaded = (try? await SupabaseManager.shared.fetchListItems(listId: currentList.id)) ?? []

        // Two batched catalog requests plus the name lookups, all at once.
        let songIds = loaded.filter { $0.kind == .song }.compactMap(\.numericRef)
        let albumIds = loaded.filter { $0.kind == .album }.compactMap(\.numericRef)
        let artistNames = loaded.filter { $0.kind == .artist }.map(\.contentRef)

        async let songsLoad = MusicService.shared.fetchTracks(ids: songIds)
        async let albumsLoad = MusicService.shared.fetchAlbums(ids: albumIds)
        async let briefsLoad = MusicService.shared.fetchArtistBriefs(names: artistNames)

        let (songs, albumsById, briefs) = await (songsLoad, albumsLoad, briefsLoad)

        await MainActor.run {
            self.items = loaded
            self.tracks = songs
            self.albums = albumsById
            self.artistBriefs = briefs
            self.isLoading = false
        }
    }

    private func reloadList() async {
        // Title and description live on the list row, which `EditListView` just rewrote.
        guard
            let lists = try? await SupabaseManager.shared.fetchLists(userId: currentList.userId),
            let updated = lists.first(where: { $0.id == currentList.id })?.list
        else { return }
        await MainActor.run { self.currentList = updated }
    }

    private func remove(_ item: MusicListItem) async {
        // Optimistic: the row disappears on the swipe, and comes back if the delete fails.
        let previous = items
        await MainActor.run { items.removeAll { $0.id == item.id } }

        do {
            try await SupabaseManager.shared.removeFromList(itemId: item.id)
            onChanged?()
        } catch {
            debugLog("List: failed to remove item:", error)
            await MainActor.run { items = previous }
        }
    }

    private func persistOrder() async {
        do {
            try await SupabaseManager.shared.reorderList(items: items)
            onChanged?()
        } catch {
            debugLog("List: failed to save new order:", error)
            // Re-read rather than guess: a partially applied reorder is worse than a reload.
            await load()
        }
    }

    private func deleteList() async {
        do {
            try await SupabaseManager.shared.deleteList(listId: currentList.id)
            onChanged?()
            await MainActor.run { dismiss() }
        } catch {
            debugLog("List: failed to delete:", error)
        }
    }
}

// MARK: - Row

private struct ListItemRow: View {
    let rank: Int
    let item: MusicListItem
    let track: Track?
    let album: Album?
    let brief: ArtistBrief?

    private var title: String {
        track?.title ?? album?.title ?? brief?.name ?? item.contentRef
    }

    private var subtitle: String? {
        track?.artist ?? album?.artist ?? (item.kind == .artist ? "Artist" : nil)
    }

    private var artworkUrl: URL? {
        track?.artworkUrl600 ?? album?.artworkUrl600 ?? brief?.artworkUrl
    }

    /// True while the catalog lookup is still outstanding — artists resolve from their own
    /// name, so they are never in this state.
    private var isUnresolved: Bool {
        item.kind != .artist && track == nil && album == nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 20, alignment: .trailing)

            Group {
                if let artworkUrl {
                    AsyncImage(url: artworkUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color.white.opacity(0.08)
                        }
                    }
                } else {
                    Color.white.opacity(0.08)
                        .overlay {
                            Image(systemName: item.kind.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: item.kind == .artist ? 26 : 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(isUnresolved ? "Loading…" : title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnresolved ? .white.opacity(0.4) : .white)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                if let note = item.note, !note.isEmpty {
                    Text(ProfanityFilter.masked(note))
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
