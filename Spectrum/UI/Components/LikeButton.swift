import SwiftUI

/// A heart that can be tapped on somebody else's log.
///
/// The feed was one-directional before this: you could read what people logged and follow
/// them, and that was the whole set of things you could do with a post. This is the smallest
/// possible reply.
///
/// The state is owned by the screen, not by the button — a feed page loads every log's count
/// in one request, and a button that fetched its own would issue thirty.
struct LikeButton: View {
    let state: LikeState
    /// Nil for your own log. Liking your own post isn't interesting, and hiding the control
    /// is clearer than showing one that refuses to work.
    let onToggle: (() -> Void)?

    @State private var bumped = false

    var body: some View {
        Button {
            guard let onToggle else { return }
            // Fire the haptic before the network call: the tap should feel answered
            // immediately, and the optimistic state flips in the same frame.
            HapticFeedback.shared.impact()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { bumped = true }
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.likedByMe ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.likedByMe ? Color(hex: "#FF2D55") : .white.opacity(0.6))
                    .scaleEffect(bumped ? 1.25 : 1)

                if state.count > 0 {
                    Text("\(state.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        // Digits don't jitter as the count changes.
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(onToggle == nil)
        .opacity(onToggle == nil ? 0.55 : 1)
        .onChange(of: bumped) { _, isBumped in
            guard isBumped else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bumped = false }
            }
        }
        .accessibilityLabel(state.likedByMe ? String(localized: "Unlike") : String(localized: "Like"))
        .accessibilityValue(state.count == 1 ? "1 like" : "\(state.count) likes")
    }
}

/// One generator for the whole app.
///
/// Creating a `UIImpactFeedbackGenerator` per tap costs a visible delay on the first one —
/// the same lesson the tab bar learned. A single prepared instance answers immediately.
@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()

    private let generator = UIImpactFeedbackGenerator(style: .light)

    private init() { generator.prepare() }

    func impact() {
        generator.impactOccurred()
        // Re-arm for the next tap; the Taptic Engine goes back to sleep otherwise.
        generator.prepare()
    }
}
