import SwiftUI

/// Stand-in for a `FeedCardView` while its song or author is still loading: the same
/// shapes in the same places, so the card fills in without the layout jumping.
struct FeedCardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    bar(width: 80, height: 10)      // artist
                    bar(width: 150, height: 18)     // title
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Capsule().frame(width: 64, height: 24)   // author pill
                        bar(width: 34, height: 10)               // rating
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)

            VStack(alignment: .leading, spacing: 6) {   // review text
                bar(width: nil, height: 12)
                bar(width: 180, height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16).frame(height: 48)   // preview button
                Circle().frame(width: 44, height: 44)                  // like
            }
        }
        .foregroundStyle(.white.opacity(0.08))
        .shimmering()
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08), lineWidth: 1.5)
        )
        .accessibilityElement()
        .accessibilityLabel(Text("Loading", bundle: appStringsBundle))
    }

    private func bar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// A soft highlight sweeping across the placeholder shapes. Holds still under Reduce Motion.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.10), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.3)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}
