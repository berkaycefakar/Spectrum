import Auth
import SwiftUI

/// Adds the Report / Block pair to any piece of user content.
///
/// Wrapped in one modifier so every review card and profile gets the same two actions with the
/// same wording — Apple checks that reporting *and* blocking both exist, and scattered
/// one-off implementations are how one of them ends up missing.
struct ModerationActions: ViewModifier {
    let contentType: ReportedContentType
    let contentRef: String?
    let authorId: UUID?
    let authorUsername: String?
    let reportedText: String?
    /// Draws a visible ⋯ button on the card as well as the long-press menu.
    ///
    /// A context menu alone is invisible: nothing on screen says the content can be reported,
    /// and "we were unable to locate a mechanism for reporting objectionable content" is the
    /// usual wording of a Guideline 1.2 rejection. On cards that fill the screen edge to edge
    /// this is the affordance a reviewer looks for.
    var showsAffordance: Bool = false
    /// Called after a successful block so the host screen can drop the content from view.
    var onBlocked: (() -> Void)?

    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var blockError: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if showsAffordance && isOtherUsersContent {
                    Menu {
                        Button { showReport = true } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button(role: .destructive) { showBlockConfirm = true } label: {
                            Label("Block \(authorUsername.map { "@\($0)" } ?? "user")", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.35), in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Report or block")
                    .padding(10)
                }
            }
            .contextMenu {
                if isOtherUsersContent {
                    Button {
                        showReport = true
                    } label: {
                        Label("Report", systemImage: "flag")
                    }

                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Block \(authorUsername.map { "@\($0)" } ?? "user")", systemImage: "hand.raised")
                    }
                }
            }
            .sheet(isPresented: $showReport) {
                ReportContentView(
                    contentType: contentType,
                    contentRef: contentRef,
                    reportedUserId: authorId,
                    reportedUsername: authorUsername,
                    reportedText: reportedText,
                    onBlockRequested: { Task { await block() } }
                )
            }
            .alert("Block \(authorUsername.map { "@\($0)" } ?? "this user")?", isPresented: $showBlockConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Block", role: .destructive) { Task { await block() } }
            } message: {
                Text("You won't see their logs or reviews, and you'll stop following each other. You can undo this in Settings.")
            }
            .alert("Couldn't block", isPresented: Binding(
                get: { blockError != nil },
                set: { if !$0 { blockError = nil } }
            )) {
                Button("OK", role: .cancel) { blockError = nil }
            } message: {
                Text(blockError ?? "")
            }
    }

    /// No point offering to report or block yourself.
    private var isOtherUsersContent: Bool {
        guard let authorId else { return false }
        return authorId != SessionStore.shared.currentUser?.id
    }

    private func block() async {
        guard let authorId else { return }
        do {
            try await SupabaseManager.shared.blockUser(authorId)
            onBlocked?()
        } catch {
            blockError = error.localizedDescription
        }
    }
}

extension View {
    /// Attaches Report / Block actions (long press) to a piece of user-generated content.
    func moderationActions(
        contentType: ReportedContentType,
        contentRef: String?,
        authorId: UUID?,
        authorUsername: String?,
        reportedText: String? = nil,
        showsAffordance: Bool = false,
        onBlocked: (() -> Void)? = nil
    ) -> some View {
        modifier(ModerationActions(
            contentType: contentType,
            contentRef: contentRef,
            authorId: authorId,
            authorUsername: authorUsername,
            reportedText: reportedText,
            showsAffordance: showsAffordance,
            onBlocked: onBlocked
        ))
    }
}
