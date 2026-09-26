import SwiftUI
// `User.id` lives in the Auth module; without this the property is invisible here.
import Supabase

/// "Add to List", from a song, album or artist page.
///
/// Picks an existing list or makes a new one in the same sheet — a separate "create a list
/// first, then come back" trip is how a feature like this goes unused.
struct AddToListView: View {
    let kind: ListItemKind
    /// Apple numeric id for songs and albums, the artist's name for artists.
    let contentRef: String
    /// What the user is adding, for the header. Purely cosmetic.
    let displayTitle: String

    @Environment(\.dismiss) private var dismiss

    @State private var summaries: [MusicListSummary] = []
    @State private var alreadyIn: Set<UUID> = []
    @State private var note = ""
    @State private var isLoading = true
    @State private var busyListId: UUID?
    @State private var showCreate = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(displayTitle)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            noteField

                            if summaries.isEmpty {
                                emptyState
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(summaries) { summary in
                                        listButton(for: summary)
                                    }
                                }
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New List")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            EditListView(list: nil) { Task { await load() } }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            TextField("Why it's on the list", text: $note, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You don't have any lists yet.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Button("Make your first list") { showCreate = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "#FF00FF"))
        }
        .padding(.vertical, 12)
    }

    private func listButton(for summary: MusicListSummary) -> some View {
        let isIn = alreadyIn.contains(summary.list.id)
        let isBusy = busyListId == summary.list.id

        return Button {
            Task { await add(to: summary.list) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.list.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(summary.itemCount == 1 ? "1 record" : "\(summary.itemCount) records")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 0)

                if isBusy {
                    ProgressView().tint(.white)
                } else if isIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#4CD964"))
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(14)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        // Adding twice is a no-op server-side, but a tappable row that can't change anything
        // is still a dead control.
        .disabled(isIn || isBusy)
        .accessibilityLabel(isIn
                            ? "\(summary.list.title), already added"
                            : "Add to \(summary.list.title)")
    }

    // MARK: - Data

    private func load() async {
        guard let userId = try? await SupabaseManager.shared.getCurrentUser()?.id else {
            await MainActor.run { isLoading = false }
            return
        }

        let loaded = (try? await SupabaseManager.shared.fetchLists(userId: userId)) ?? []

        // Which lists already hold this record, so the sheet can say so instead of letting
        // the user tap and watch nothing happen.
        var containing: Set<UUID> = []
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for summary in loaded {
                group.addTask {
                    let items = (try? await SupabaseManager.shared
                        .fetchListItems(listId: summary.list.id)) ?? []
                    let has = items.contains { $0.kind == kind && $0.contentRef == contentRef }
                    return (summary.list.id, has)
                }
            }
            for await (id, has) in group where has { containing.insert(id) }
        }

        await MainActor.run {
            self.summaries = loaded
            self.alreadyIn = containing
            self.isLoading = false
        }
    }

    private func add(to list: MusicList) async {
        await MainActor.run {
            busyListId = list.id
            errorMessage = nil
        }
        defer { Task { @MainActor in busyListId = nil } }

        do {
            try await SupabaseManager.shared.addToList(
                listId: list.id,
                kind: kind,
                contentRef: contentRef,
                note: note
            )
            await MainActor.run {
                alreadyIn.insert(list.id)
                // Reflect the new count without a round-trip.
                if let index = summaries.firstIndex(where: { $0.list.id == list.id }) {
                    summaries[index] = MusicListSummary(
                        list: summaries[index].list,
                        itemCount: summaries[index].itemCount + 1
                    )
                }
            }
        } catch {
            // The note goes through the profanity filter, so this can genuinely fail on
            // something the user typed and has to be told about.
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
