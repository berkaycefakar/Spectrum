import SwiftUI
import Supabase

/// Written replies under a log, with a field to add one.
///
/// Long-press a comment to delete it (your own, or any on your own log) or to report or
/// block its author. Comments from people you've blocked are never fetched into view.
struct LogCommentsSection: View {
    let contentType: ReportedContentType
    let contentId: UUID
    /// The log's author: they may delete any comment under it.
    let logOwnerId: UUID
    var accent: Color = .spectrumAccent

    @State private var comments: [ReviewComment] = []
    @State private var profiles: [UUID: Profile] = [:]
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var loaded = false
    @FocusState private var fieldFocused: Bool
    @ObservedObject private var session = SessionStore.shared

    private var me: UUID? { session.currentUser?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("Comments", bundle: appStringsBundle)
                    .font(.headline)
                    .foregroundStyle(.white)
                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            ForEach(comments) { comment in
                row(comment)
            }

            if loaded && comments.isEmpty {
                Text("No comments yet.", bundle: appStringsBundle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
            }

            composer

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#FF6B6B"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await load() }
    }

    private func row(_ comment: ReviewComment) -> some View {
        let profile = profiles[comment.userId]
        let name = profile?.username ?? String(localized: "User", bundle: appStringsBundle)
        let canDelete = comment.userId == me || logOwnerId == me
        return HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: AppRoute.user(comment.userId)) {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    NavigationLink(value: AppRoute.user(comment.userId)) {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    Text(comment.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(ProfanityFilter.masked(comment.body))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .moderationActions(
            contentType: .comment,
            contentRef: comment.id.uuidString,
            authorId: comment.userId,
            authorUsername: profile?.username,
            reportedText: comment.body,
            onBlocked: { Task { await load() } },
            onDelete: canDelete ? { Task { await delete(comment) } } : nil
        )
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                String(localized: "Add a comment…", bundle: appStringsBundle),
                text: $draft,
                axis: .vertical
            )
            .focused($fieldFocused)
            .lineLimit(1...4)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .onChange(of: draft) { _, new in
                if new.count > SupabaseManager.commentMaxLength {
                    draft = String(new.prefix(SupabaseManager.commentMaxLength))
                }
                errorMessage = nil
            }

            Button {
                Task { await send() }
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 38, height: 38)
                .background(Circle().fill(canSend ? accent : .white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel(Text("Send comment", bundle: appStringsBundle))
        }
    }

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() async {
        guard let rows = try? await SupabaseManager.shared.fetchComments(contentType: contentType, contentId: contentId) else {
            loaded = true
            return
        }
        comments = rows
        await loadProfiles(for: rows)
        loaded = true
    }

    private func loadProfiles(for rows: [ReviewComment]) async {
        let missing = Set(rows.map(\.userId)).subtracting(profiles.keys)
        guard !missing.isEmpty else { return }
        let fetched = (try? await SupabaseManager.shared.batchGetProfiles(ids: missing.map(\.uuidString))) ?? []
        for profile in fetched { profiles[profile.id] = profile }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await SupabaseManager.shared.addComment(
                contentType: contentType, contentId: contentId, body: draft
            )
            comments.append(comment)
            draft = ""
            fieldFocused = false
            await loadProfiles(for: [comment])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ comment: ReviewComment) async {
        let index = comments.firstIndex(of: comment)
        comments.removeAll { $0.id == comment.id }
        do {
            try await SupabaseManager.shared.deleteComment(id: comment.id)
        } catch {
            if let index { comments.insert(comment, at: min(index, comments.count)) }
            errorMessage = error.localizedDescription
        }
    }
}
