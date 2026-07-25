import SwiftUI

/// Google's four-colour "G", drawn rather than bundled.
///
/// The sign-in row previously used the `globe` SF Symbol, which reads as "some website" and
/// not as Google at all. There is no Google glyph in SF Symbols, so this constructs the mark
/// from the shape it actually is: a ring split into four coloured arcs, with the blue crossbar
/// running in from the right at the vertical centre.
///
/// - Note: Google's Identity Guidelines require their *official* asset on a "Sign in with
///   Google" button. Before release, drop the real SVG/PDF into the asset catalogue and swap
///   this out — see APP_STORE_READINESS.md. This keeps the button honest in the meantime
///   without shipping a logo file that isn't Google's own.
struct GoogleGMark: View {
    var size: CGFloat = 18

    // Google's brand palette.
    private let blue = Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)
    private let green = Color(red: 52 / 255, green: 168 / 255, blue: 83 / 255)
    private let yellow = Color(red: 251 / 255, green: 188 / 255, blue: 5 / 255)
    private let red = Color(red: 234 / 255, green: 67 / 255, blue: 53 / 255)

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = side / 2
            let thickness = side * 0.22
            let radius = outer - thickness / 2

            // Angles are clockwise from 3 o'clock, because SwiftUI's y axis points down.
            // The ring is interrupted on the right, where the crossbar enters.
            let segments: [(Color, Double, Double)] = [
                (green, 18, 110),    // 4 o'clock → 7 o'clock
                (yellow, 110, 182),  // 7 o'clock → 9 o'clock
                (red, 182, 292),     // 9 o'clock → over the top → 1 o'clock
                (blue, 292, 356)     // 1 o'clock → just short of the bar
            ]

            for (color, start, end) in segments {
                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .butt)
                )
            }

            // The crossbar: starts at the centre and runs out to the ring, sitting just below
            // the horizontal midline — this is the stroke that turns an "O" into a "G".
            let bar = Path(
                CGRect(
                    x: center.x - thickness * 0.1,
                    y: center.y - thickness / 2,
                    width: outer + thickness * 0.1,
                    height: thickness
                )
            )
            context.fill(bar, with: .color(blue))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            GoogleGMark(size: 18)
            GoogleGMark(size: 48)
            GoogleGMark(size: 96)
        }
    }
}
