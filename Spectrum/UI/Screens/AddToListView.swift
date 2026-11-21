import SwiftUI
// `User.id` lives in the Auth module; without this the property is invisible here.
import Supabase

/// "Add to a list", from a song, album or artist page.
///
/// Each list shows its first covers fanned out, so lists are recognised by what's in them
/// rather than by name alone. Tapping a row adds the record, tapping again takes it out.
/// A new list can be made from the same sheet.
struct AddToListView: View {
    let kind: ListItemKind
    /// Apple numeric id for songs and albums, the artist's name for artists.
    let contentRef: String
    /// What the user is adding, for the header. Purely cosmetic.
    let displayTitle: String

    @Environment(\.dismiss) private var dismiss

    @State private var summaries: [MusicListSummary] = []
    /// Lists that already hold a different kind of thing, left out: a list is all songs, all
    /// albums or all artists, set by its first entry.
    @State private var otherKindCount = 0
    /// List id → the item id of this record in it, for the lists that already hold it.
    @State private var membership: [UUID: UUID] = [:]
    /// List id → up to three cover URLs, in list order.
    @State private var covers: [UUID: [URL]] = [:]
    @State private var note = ""
    @State private var query = ""
    @State private var isLoading = true
    @State private var busyListId: UUID?
    @State private var showCreate = false
    @State private var errorMessage: String?

    private var shown: [MusicListSummary] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return summaries }
        return summaries.filter { $0.list.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Add to a list", bundle: appStringsBundle)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button { showCreate = true } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.white.opacity(0.1), in: Circle())
                                }
                                .accessibilityLabel("New List")
                                Button { dismiss() } label: {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.black)
                                        .frame(width: 36, height: 36)
                                        .background(Color.white, in: Circle())
                                }
                                .accessibilityLabel(Text("Done", bundle: appStringsBundle))
                            }
                            Text(displayTitle)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)

                            if summaries.count > 5 {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                                    TextField(String(localized: "Search your lists", bundle: appStringsBundle), text: $query)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 42)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            }

                            if summaries.isEmpty && otherKindCount == 0 {
                                emptyState
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(shown) { summary in
                                        listRow(summary)
                                    }
                                    if summaries.isEmpty {
                                        emptyState
                                    }
                                }
                                if otherKindCount > 0 {
                                    Text(otherKindNote)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }

                            TextField(
                                String(localized: "Why it's on the list (optional)", bundle: appStringsBundle),
                                text: $note,
                                axis: .vertical
                            )
                            .lineLimit(1...3)
                            .font(.subheadline)
                            .padding(12)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                            .padding(.top, 4)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(Color(hex: "#FF6B6B"))
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            EditListView(list: nil) { Task { await load() } }
        }
    }

    private var otherKindNote: String {
        switch kind {
        case .song: String(localized: "Lists of albums or artists aren't shown here.", bundle: appStringsBundle)
        case .album: String(localized: "Lists of songs or artists aren't shown here.", bundle: appStringsBundle)
        case .artist: String(localized: "Lists of songs or albums aren't shown here.", bundle: appStringsBundle)
        }
    }

    private var emptyState: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "plus").foregroundStyle(.white.opacity(0.6)))
                Text("Make your first list", bundle: appStringsBundle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(12)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    /// The list's first covers, overlapping like records in a crate.
    private func coverStack(_ urls: [URL]) -> some View {
        HStack(spacing: -26) {
            if urls.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "music.note.list").font(.caption).foregroundStyle(.white.opacity(0.4)))
            }
            ForEach(Array(urls.prefix(3).enumerated()), id: \.offset) { index, url in
                AsyncImage(url: url) { phase in
                    (phase.image?.resizable() ?? Image(systemName: "music.note").resizable())
                        .aspectRatio(contentMode: .fill)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.6), radius: 4, x: -2)
                .zIndex(Double(-index))
            }
        }
        .frame(width: 104, alignment: .leading)
    }

    private func listRow(_ summary: MusicListSummary) -> some View {
        let isIn = membership[summary.list.id] != nil
        let isBusy = busyListId == summary.list.id

        return Button {
            Task { await toggle(summary.list) }
        } label: {
            HStack(spacing: 12) {
                coverStack(covers[summary.list.id] ?? [])
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.list.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(summary.itemCount == 1 ? "1 record" : "\(summary.itemCount) records")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer(minLength: 0)
                Group {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text(isIn ? String(localized: "Added", bundle: appStringsBundle)
                                  : String(localized: "Add", bundle: appStringsBundle))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isIn ? Color.spectrumAccent : .white.opacity(0.7))
                    }
                }
                .frame(minWidth: 52, alignment: .trailing)
            }
            .padding(12)
            .background(isIn ? Color.spectrumAccent.opacity(0.12) : .white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isIn ? Color.spectrumAccent : .clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(summary.list.title)
        .accessibilityValue(isIn ? String(localized: "Added", bundle: appStringsBundle) : "")
        .accessibilityHint(isIn ? String(localized: "Removes it from this list", bundle: appStringsBundle)
                                : String(localized: "Adds it to this list", bundle: appStringsBundle))
    }

    // MARK: - Data

    private func load() async {
        guard let userId = try? await SupabaseManager.shared.getCurrentUser()?.id else {
            isLoading = false
            return
        }

        let loaded = (try? await SupabaseManager.shared.fetchLists(userId: userId)) ?? []

        // Every list's items, once: they say which lists already hold this record and give
        // each list's first covers.
        var itemsByList: [UUID: [MusicListItem]] = [:]
        await withTaskGroup(of: (UUID, [MusicListItem]).self) { group in
            for summary in loaded {
                group.addTask {
                    let items = (try? await SupabaseManager.shared.fetchListItems(listId: summary.list.id)) ?? []
                    return (summary.list.id, items)
                }
            }
            for await (id, items) in group { itemsByList[id] = items }
        }

        var members: [UUID: UUID] = [:]
        for (listId, items) in itemsByList {
            if let hit = items.first(where: { $0.kind == kind && $0.contentRef == contentRef }) {
                members[listId] = hit.id
            }
        }

        // First three songs/albums per list, resolved in two batched lookups.
        let firsts = itemsByList.mapValues { Array($0.filter { $0.kind != .artist }.prefix(3)) }
        let songIds = firsts.values.flatMap { $0 }.filter { $0.kind == .song }.compactMap(\.numericRef)
        let albumIds = firsts.values.flatMap { $0 }.filter { $0.kind == .album }.compactMap(\.numericRef)
        async let songs = songIds.isEmpty ? [:] : MusicService.shared.fetchTracks(ids: songIds)
        async let albums = albumIds.isEmpty ? [:] : MusicService.shared.fetchAlbums(ids: albumIds)
        let (s, a) = await (songs, albums)
        let coverMap = firsts.mapValues { items in
            items.compactMap { item -> URL? in
                guard let id = item.numericRef else { return nil }
                return item.kind == .song ? s[id]?.artworkUrl600 : a[id]?.artworkUrl600
            }
        }

        let fitting = loaded.filter { summary in
            guard let first = itemsByList[summary.list.id]?.first else { return true }
            return first.kind == kind
        }
        otherKindCount = loaded.count - fitting.count
        summaries = fitting
        membership = members
        // A cover photo the owner picked leads the stack.
        covers = coverMap.merging(
            Dictionary(uniqueKeysWithValues: loaded.compactMap { s in
                s.list.coverUrl.flatMap(URL.init(string:)).map { (s.list.id, [$0]) }
            }),
            uniquingKeysWith: { records, cover in Array((cover + records).prefix(3)) }
        )
        isLoading = false
    }

    private func toggle(_ list: MusicList) async {
        busyListId = list.id
        errorMessage = nil
        defer { busyListId = nil }

        do {
            if let itemId = membership[list.id] {
                try await SupabaseManager.shared.removeFromList(itemId: itemId)
                membership[list.id] = nil
                bumpCount(list.id, by: -1)
            } else {
                try await SupabaseManager.shared.addToList(
                    listId: list.id, kind: kind, contentRef: contentRef, note: note
                )
                // The new row's id is needed to take it out again; read it back.
                let items = (try? await SupabaseManager.shared.fetchListItems(listId: list.id)) ?? []
                membership[list.id] = items.first { $0.kind == kind && $0.contentRef == contentRef }?.id
                bumpCount(list.id, by: 1)
            }
        } catch {
            // The note goes through the profanity filter, so adding can genuinely fail on
            // something the user typed.
            errorMessage = error.localizedDescription
        }
    }

    private func bumpCount(_ listId: UUID, by delta: Int) {
        guard let index = summaries.firstIndex(where: { $0.list.id == listId }) else { return }
        summaries[index] = MusicListSummary(list: summaries[index].list,
                                            itemCount: max(0, summaries[index].itemCount + delta))
    }
}
