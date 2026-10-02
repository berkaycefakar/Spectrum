import SwiftUI

/// Search the catalog and add straight into one list.
///
/// The only way into a list used to be the other direction: open a song, tap "Add to List",
/// pick the list. That works when you already have the record in front of you, and is useless
/// when you have just made "best of 2026" and want to fill it — the list opened empty and told
/// you to go and find things elsewhere. This is the same sheet from the list's side.
struct AddRecordsToListView: View {
    let list: MusicList
    /// Whatever the list already holds, so rows can say "added" rather than letting the user
    /// tap something that can't change.
    let existing: Set<String>
    /// Called after every successful add, so the list behind the sheet stays current.
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var kind: ListItemKind = .song
    @State private var query = ""
    @State private var tracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    /// Refs added in this sheet, on top of `existing`. Local so the row flips the moment the
    /// write lands, without waiting for the parent to refetch.
    @State private var added: Set<String> = []
    @State private var busyRef: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    kindPicker
                    searchField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    results
                }
                .padding(.top, 12)
            }
            .navigationTitle("Add to “\(list.title)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        // A sheet dragged away mid-search would otherwise leave the request running.
        .onDisappear { searchTask?.cancel() }
    }

    // MARK: - Chrome

    private var kindPicker: some View {
        Picker("What to add", selection: $kind) {
            ForEach(ListItemKind.allCases, id: \.self) { kind in
                Text(kind.label).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        // Switching tabs re-runs the same query against the other catalog rather than
        // clearing it — you are usually looking for the same name either way.
        .onChange(of: kind) { _, _ in scheduleSearch(query) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))

            TextField(placeholder, text: $query)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await search(query) } }
                .onChange(of: query) { _, newValue in scheduleSearch(newValue) }

            if !query.isEmpty {
                Button {
                    query = ""
                    clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var placeholder: String {
        switch kind {
        case .song: String(localized: "Search songs")
        case .album: String(localized: "Search albums")
        case .artist: String(localized: "Search artists")
        }
    }

    @ViewBuilder
    private var results: some View {
        if isSearching && isEmptyResults {
            Spacer()
            ProgressView().tint(.white)
            Spacer()
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer()
            hint
            Spacer()
        } else if isEmptyResults {
            Spacer()
            Text("Nothing found for “\(query)”.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    switch kind {
                    case .song:
                        ForEach(tracks) { track in
                            row(
                                ref: String(track.id),
                                title: track.title,
                                subtitle: track.artist,
                                artwork: track.artworkUrl600,
                                isCircular: false
                            )
                        }
                    case .album:
                        ForEach(albums) { album in
                            row(
                                ref: String(album.id),
                                title: album.title,
                                subtitle: album.artist,
                                artwork: album.artworkUrl600,
                                isCircular: false
                            )
                        }
                    case .artist:
                        ForEach(artists) { artist in
                            row(
                                ref: artist.name,
                                title: artist.name,
                                subtitle: artist.genres.first,
                                artwork: artist.artworkUrl,
                                isCircular: true
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    private var hint: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.25))
            Text("Search for something to add")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var isEmptyResults: Bool {
        switch kind {
        case .song: tracks.isEmpty
        case .album: albums.isEmpty
        case .artist: artists.isEmpty
        }
    }

    // MARK: - Row

    private func row(
        ref: String,
        title: String,
        subtitle: String?,
        artwork: URL?,
        isCircular: Bool
    ) -> some View {
        let isIn = existing.contains(ref) || added.contains(ref)
        let isBusy = busyRef == ref

        return Button {
            Task { await add(ref: ref) }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: artwork) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.08)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: isCircular ? 26 : 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if isBusy {
                    ProgressView().tint(.white)
                } else if isIn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "#4CD964"))
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "#FF00FF"))
                }
            }
            .padding(12)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isIn || isBusy)
        .accessibilityLabel(isIn
                            ? String(localized: "\(title), already in this list")
                            : String(localized: "Add \(title)"))
    }

    // MARK: - Search

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        guard text.trimmingCharacters(in: .whitespaces).count >= 2 else {
            clearResults()
            return
        }
        searchTask = Task {
            // Same 350ms as the Search tab — long enough to coalesce a burst of typing,
            // short enough that results don't feel like they lag behind the keyboard.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(text)
        }
    }

    private func search(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        await MainActor.run { isSearching = true }

        // One catalog per tab: searching all three would triple the request count for results
        // the user can't see.
        switch kind {
        case .song:
            let found = (try? await MusicService.shared.search(query: trimmed)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run { tracks = found }
        case .album:
            let found = (try? await MusicService.shared.searchAlbums(query: trimmed)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run { albums = found }
        case .artist:
            let found = (try? await MusicService.shared.searchArtists(query: trimmed)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run { artists = found }
        }

        await MainActor.run { isSearching = false }
    }

    private func clearResults() {
        tracks = []
        albums = []
        artists = []
        isSearching = false
    }

    // MARK: - Write

    private func add(ref: String) async {
        await MainActor.run {
            busyRef = ref
            errorMessage = nil
        }
        defer { Task { @MainActor in busyRef = nil } }

        do {
            try await SupabaseManager.shared.addToList(
                listId: list.id,
                kind: kind,
                contentRef: ref
            )
            await MainActor.run { added.insert(ref) }
            onAdded()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
