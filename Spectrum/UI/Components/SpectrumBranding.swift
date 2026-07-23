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

/// Small prism mark: a white beam entering a glass triangle and dispersing into the spectrum.
/// A compact echo of the app icon, for use in headers.
struct SpectrumMark: View {
    var size: CGFloat = 30

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width
            let cx = s * 0.46
            let cy = s * 0.52
            let side = s * 0.6
            let h = side * 0.866
            let top = CGPoint(x: cx, y: cy - h * 0.58)
            let left = CGPoint(x: cx - side / 2, y: cy + h * 0.42)
            let right = CGPoint(x: cx + side / 2, y: cy + h * 0.42)
            let exit = CGPoint(x: (top.x + right.x) / 2 + s * 0.02, y: (top.y + right.y) / 2)

            // Rainbow fan
            let n = SpectrumPalette.colors.count
            let fan = 52.0
            let start = 34.0 - fan / 2
            let step = fan / Double(n - 1)
            let length = s * 0.62
            for (i, col) in SpectrumPalette.colors.enumerated() {
                let ang = (start + step * Double(i)) * .pi / 180
                let hw = (step * 0.46) * .pi / 180
                var path = Path()
                path.move(to: exit)
                path.addLine(to: CGPoint(x: exit.x + length * cos(ang - hw), y: exit.y + length * sin(ang - hw)))
                path.addLine(to: CGPoint(x: exit.x + length * cos(ang + hw), y: exit.y + length * sin(ang + hw)))
                path.closeSubpath()
                context.fill(path, with: .color(col))
            }

            // Incoming white beam
            var beam = Path()
            let entry = CGPoint(x: (top.x + left.x) / 2, y: (top.y + left.y) / 2)
            beam.move(to: CGPoint(x: 0, y: 0))
            beam.addLine(to: CGPoint(x: entry.x, y: entry.y))
            context.stroke(beam, with: .color(.white.opacity(0.9)), lineWidth: s * 0.05)

            // Glass prism
            var tri = Path()
            tri.move(to: top); tri.addLine(to: left); tri.addLine(to: right); tri.closeSubpath()
            context.fill(tri, with: .color(.white.opacity(0.12)))
            context.stroke(tri, with: .color(.white), lineWidth: s * 0.055)
        }
        .frame(width: size, height: size)
    }
}

/// "Spectrum" wordmark. Solid white by design — the colour lives in the prism mark, not the
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

/// Branded launch/splash screen: the prism mark and wordmark on the app's neon backdrop,
/// with a gentle entrance animation. Shown while the session is being checked.
struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            // Neon backdrop matching the app icon.
            LinearGradient(
                colors: [Color(hex: "#3A0C4A"), Color(hex: "#0A0616")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "#9652FF").opacity(0.28))
                .frame(width: 320, height: 320)
                .blur(radius: 90)

            VStack(spacing: 20) {
                SpectrumMark(size: 96)
                    .shadow(color: Color(hex: "#9652FF").opacity(0.5), radius: 24)
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
