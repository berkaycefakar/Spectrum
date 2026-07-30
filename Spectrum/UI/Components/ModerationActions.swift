import Auth
import SwiftUI

/// The piece of content a Report / Block action is about.
///
/// Shared by the two entry points below so the wording, the "is this mine?" test and the block
/// call itself can't drift apart — Apple checks that reporting *and* blocking both exist, and
/// scattered one-off implementations are how one of them ends up missing.
struct ModerationTarget {
    let contentType: ReportedContentType
    let contentRef: String?
    let authorId: UUID?
    let authorUsername: String?
    let reportedText: String?

    /// No point offering to report or block yourself.
    var isOtherUsersContent: Bool {
        guard let authorId else { return false }
        return authorId != SessionStore.shared.currentUser?.id
    }

    var blockTitle: String { "Block \(authorUsername.map { "@\($0)" } ?? "user")" }

    func block() async throws {
        guard let authorId else { return }
        try await SupabaseManager.shared.blockUser(authorId)
    }
}

/// Report / Block as a tappable ⋯ menu, for a toolbar or anywhere a visible control belongs.
///
/// This is the discoverable half of the requirement. The long-press menu below is a shortcut;
/// on its own it is invisible, and "we were unable to locate a mechanism for reporting
/// objectionable content" is the usual wording of a Guideline 1.2 rejection.
struct ModerationMenu: View {
    let target: ModerationTarget
    var onBlocked: (() -> Void)?

    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var blockError: String?

    var body: some View {
        Group {
            if target.isOtherUsersContent {
                Menu {
                    Button { showReport = true } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label(target.blockTitle, systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Report or block")
                .moderationDialogs(
                    target: target,
                    showReport: $showReport,
                    showBlockConfirm: $showBlockConfirm,
                    blockError: $blockError,
                    onBlocked: onBlocked
                )
            }
        }
    }
}

/// Report / Block on long press, for cards in a list where a permanent badge would be noise.
struct ModerationActions: ViewModifier {
    let target: ModerationTarget
    var onBlocked: (() -> Void)?

    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var blockError: String?

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if target.isOtherUsersContent {
                    Button { showReport = true } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label(target.blockTitle, systemImage: "hand.raised")
                    }
                }
            }
            .moderationDialogs(
                target: target,
                showReport: $showReport,
                showBlockConfirm: $showBlockConfirm,
                blockError: $blockError,
                onBlocked: onBlocked
            )
    }
}

/// The sheet and the two alerts, identical for both entry points.
private struct ModerationDialogs: ViewModifier {
    let target: ModerationTarget
    @Binding var showReport: Bool
    @Binding var showBlockConfirm: Bool
    @Binding var blockError: String?
    var onBlocked: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showReport) {
                ReportContentView(
                    contentType: target.contentType,
                    contentRef: target.contentRef,
                    reportedUserId: target.authorId,
                    reportedUsername: target.authorUsername,
                    reportedText: target.reportedText,
                    onBlockRequested: { Task { await block() } }
                )
            }
            .alert("Block \(target.authorUsername.map { "@\($0)" } ?? "this user")?", isPresented: $showBlockConfirm) {
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

    private func block() async {
        do {
            try await target.block()
            onBlocked?()
        } catch {
            blockError = error.localizedDescription
        }
    }
}

private extension View {
    func moderationDialogs(
        target: ModerationTarget,
        showReport: Binding<Bool>,
        showBlockConfirm: Binding<Bool>,
        blockError: Binding<String?>,
        onBlocked: (() -> Void)?
    ) -> some View {
        modifier(ModerationDialogs(
            target: target,
            showReport: showReport,
            showBlockConfirm: showBlockConfirm,
            blockError: blockError,
            onBlocked: onBlocked
        ))
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
        onBlocked: (() -> Void)? = nil
    ) -> some View {
        modifier(ModerationActions(
            target: ModerationTarget(
                contentType: contentType,
                contentRef: contentRef,
                authorId: authorId,
                authorUsername: authorUsername,
                reportedText: reportedText
            ),
            onBlocked: onBlocked
        ))
    }
}
