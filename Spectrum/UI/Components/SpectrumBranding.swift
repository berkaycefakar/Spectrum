import SwiftUI

/// The Spectrum colour order, reused across the logo, wordmark and accents.
enum SpectrumPalette {
    static let colors: [Color] = [
        Color(hex: "#FF2D55"), Color(hex: "#FF9500"), Color(hex: "#FFD60A"),
        Color(hex: "#34DC78"), Color(hex: "#5AC8FA"), Color(hex: "#0A84FF"),
        Color(hex: "#9652FF")
    ]

    static var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

/// Small mark: a cream speech bubble holding a five-bar waveform in the spectrum colours.
/// The app icon without its ink tile, for use on the app's dark screens.
struct SpectrumMark: View {
    var size: CGFloat = 30

    /// The bars' colours, left to right. Deeper than `SpectrumPalette` so they hold up on cream.
    private static let barColors: [Color] = [
        Color(hex: "#E0247F"), Color(hex: "#F26A12"), Color(hex: "#E8B400"),
        Color(hex: "#12A99B"), Color(hex: "#4B3BE0")
    ]
    /// Bar heights as a fraction of the bubble's height, from the icon's geometry.
    private static let barHeights: [CGFloat] = [120, 230, 320, 200, 270].map { $0 / 480 }

    var body: some View {
        Canvas { context, canvasSize in
            // The icon draws this on a 1024 grid; the bubble and its tail span 660 of it, so
            // `u` maps icon units onto the frame and the mark fills it edge to edge.
            let u = canvasSize.width / 660
            let ox = -182 * u
            let oy = (canvasSize.height - 620 * u) / 2 - 232 * u
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * u, y: oy + y * u) }

            let cream = Color(hex: "#F4EFE6")
            let bubble = Path(
                roundedRect: CGRect(origin: p(196, 232), size: CGSize(width: 632 * u, height: 480 * u)),
                cornerRadius: 130 * u
            )
            context.fill(bubble, with: .color(cream))

            var tail = Path()
            tail.move(to: p(292, 650)); tail.addLine(to: p(236, 838)); tail.addLine(to: p(462, 700))
            tail.closeSubpath()
            context.fill(tail, with: .color(cream))
            context.stroke(tail, with: .color(cream), style: StrokeStyle(lineWidth: 24 * u, lineJoin: .round))

            for (i, color) in Self.barColors.enumerated() {
                let h = Self.barHeights[i] * 480
                let bar = Path(
                    roundedRect: CGRect(origin: p(324 + CGFloat(i) * 80, 472 - h / 2), size: CGSize(width: 56 * u, height: h * u)),
                    cornerRadius: 28 * u
                )
                context.fill(bar, with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "Spectrum" wordmark. Solid white by design — the colour lives in the mark, not the
/// letters, so the name stays clean and legible.
struct SpectrumWordmark: View {
    var size: CGFloat = 30

    var body: some View {
        Text("Spectrum")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .tracking(0.5)
    }
}

/// Branded launch/splash screen: the mark and wordmark on the app's dark backdrop,
/// with a gentle entrance animation. Shown while the session is being checked.
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            // Flat ink, the app icon's own tile, so launching from the icon reads as one surface.
            Color(hex: "#0E0A14")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                SpectrumMark(size: 96)
                    .scaleEffect(appear ? 1 : 0.8)
                    .opacity(appear ? 1 : 0)

                SpectrumWordmark(size: 34)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)

                Text("Rate. Log. Discover.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(1)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true }
        }
    }
}

#Preview {
    SplashView()
}
