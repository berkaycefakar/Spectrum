import SwiftUI

// MARK: - Lists on a profile

/// The lists section of a profile.
///
/// Shown on your own profile and on other people's — RLS is what decides whether private
/// lists come back, so this view draws whatever it is given rather than filtering itself.
struct ProfileListsSection: View {
    let userId: UUID
    let isOwner: Bool

    @State private var summaries: [MusicListSummary] = []
    @State private var isLoading = true
    @State private var showCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Lists")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if isOwner {
                    Button {
                        showCreate = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("New")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: "#FF00FF"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New List")
                }
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if summaries.isEmpty {
                Text(isOwner
                     ? "No lists yet. Make one — “best of 2026”, “songs for driving at night”."
                     : "No public lists.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(summaries) { summary in
                        NavigationLink(destination: ListDetailView(
                            list: summary.list,
                            isOwner: isOwner,
                            onChanged: { Task { await load() } }
                        )) {
                            ListRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            EditListView(list: nil) { Task { await load() } }
        }
    }

    private func load() async {
        let loaded = (try? await SupabaseManager.shared.fetchLists(userId: userId)) ?? []
        await MainActor.run {
            self.summaries = loaded
            self.isLoading = false
        }
    }
}

private struct ListRow: View {
    let summary: MusicListSummary

    private var subtitle: String {
        let count = summary.itemCount
        return count == 1 ? "1 record" : "\(count) records"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(summary.list.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // Only meaningful on your own profile — on someone else's, everything
                    // you can see is public by definition. Shown anyway rather than
                    // conditioned on ownership: a wrong badge is worse than a redundant one.
                    if !summary.list.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                            .accessibilityLabel("Private")
                    }
                }

                if let description = summary.list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Create / edit

struct EditListView: View {
    /// Nil when creating.
    let list: MusicList?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { list != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("“Best albums of 2026”, “songs for driving at night”.")
                }

                Section {
                    Toggle("Public", isOn: $isPublic)
                } footer: {
                    Text(isPublic
                         ? "Anyone can open this list from your profile."
                         : "Only you can see this list.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard let list else { return }
            title = list.title
            description = list.description ?? ""
            isPublic = list.isPublic
        }
    }

    private func save() async {
        guard canSave else { return }
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        do {
            if let list {
                try await SupabaseManager.shared.updateList(
                    listId: list.id,
                    title: title,
                    description: description,
                    isPublic: isPublic
                )
            } else {
                try await SupabaseManager.shared.createList(
                    title: title,
                    description: description,
                    isPublic: isPublic
                )
            }
            await MainActor.run {
                isSaving = false
                onSaved()
                dismiss()
            }
        } catch {
            // Surfaced, not swallowed: the profanity filter and the title-length constraint
            // both reject through here, and "Save did nothing" is the worst possible answer.
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
