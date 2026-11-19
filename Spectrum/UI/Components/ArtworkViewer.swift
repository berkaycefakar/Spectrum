import SwiftUI

/// A cover, full screen. Tap, the close button or a swipe down puts it away; pinch zooms.
struct ArtworkViewer: View {
    let url: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var drag: CGFloat = 0

    /// Apple's artwork URLs carry their size ("…/600x600bb.jpg"); ask for a sharper one.
    private var largeURL: URL? {
        guard let url else { return nil }
        let s = url.absoluteString.replacingOccurrences(of: "600x600bb", with: "1500x1500bb")
            .replacingOccurrences(of: "100x100bb", with: "1500x1500bb")
        return URL(string: s) ?? url
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - min(abs(drag) / 400, 0.6))
                .ignoresSafeArea()

            AsyncImage(url: largeURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    // The small cover is usually cached already; show it while the big one loads.
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fit) } placeholder: {
                        ProgressView().tint(.white)
                    }
                }
            }
            .scaleEffect(scale)
            .offset(y: drag)
            .padding(.horizontal, 12)
            .gesture(
                MagnifyGesture()
                    .onChanged { scale = max(1, $0.magnification) }
                    .onEnded { _ in withAnimation(.spring) { scale = 1 } }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { if scale == 1 { drag = $0.translation.height } }
                    .onEnded { value in
                        if abs(value.translation.height) > 120 { dismiss() }
                        else { withAnimation(.spring) { drag = 0 } }
                    }
            )
            .onTapGesture { dismiss() }
            .accessibilityLabel(Text("Cover art", bundle: appStringsBundle))
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(16)
            .accessibilityLabel(Text("Close", bundle: appStringsBundle))
        }
        .statusBarHidden()
    }
}
