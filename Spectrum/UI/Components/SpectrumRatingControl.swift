import SwiftUI
import UIKit

/// The rating dial: a half-circle like an amp's volume knob. Drag along the arc (or tap a point
/// on it) to set the score, in tenths: 4.2 and 4.3 are both possible, 4.25 is not. The score sits
/// big in the middle. Light ticks mark every whole and half star; a soft click every tenth and a
/// firmer one on each half star.
struct SpectrumRatingControl: View {
    /// Rating value in the range 0...5, in 0.1 steps. Zero means "not rated yet".
    @Binding var rating: Double
    var accentColor: Color = Color.spectrumAccent
    /// The top of the scale.
    var maxRating: Int = 5
    /// Size multiplier: the log sheet on a short phone needs a smaller dial.
    var scale: CGFloat = 1

    @State private var selection = UISelectionFeedbackGenerator()
    @State private var impact = UIImpactFeedbackGenerator(style: .soft)

    private var width: CGFloat { 250 * scale }
    private var lineWidth: CGFloat { 12 * scale }
    private var radius: CGFloat { width / 2 - 22 * scale }
    private var height: CGFloat { radius + 22 * scale + lineWidth }
    private var center: CGPoint { CGPoint(x: width / 2, y: height - lineWidth) }
    private var fraction: Double { min(max(rating / Double(maxRating), 0), 1) }

    var body: some View {
        ZStack {
            ticks
            arc.stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            arc.trim(from: 0, to: fraction)
                .stroke(
                    LinearGradient(colors: [accentColor.opacity(0.65), accentColor], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .shadow(color: accentColor.opacity(0.45), radius: 8)
            knob
            VStack(spacing: 0) {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 46 * scale, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rating > 0 ? .white : .white.opacity(0.3))
                    .contentTransition(.numericText(value: rating))
                Text("out of 5", bundle: appStringsBundle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .position(x: center.x, y: center.y - 30 * scale)
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { update(at: $0.location) }
                .onEnded { _ in impact.impactOccurred(intensity: 0.6) }
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .onAppear { selection.prepare(); impact.prepare() }
        .accessibilityElement()
        .accessibilityLabel(Text("Rating", bundle: appStringsBundle))
        .accessibilityValue(String(format: "%.1f / %d", rating, maxRating))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(Double(maxRating), ((rating + 0.1) * 10).rounded() / 10)
            case .decrement: rating = max(0.1, ((rating - 0.1) * 10).rounded() / 10)
            @unknown default: break
            }
        }
    }

    /// Point on the arc at `t` (0 = left end, 1 = right end), over the top.
    private func point(_ t: Double, r: CGFloat? = nil) -> CGPoint {
        let a = Double.pi + Double.pi * t
        let rr = r ?? radius
        return CGPoint(x: center.x + rr * CGFloat(cos(a)), y: center.y + rr * CGFloat(sin(a)))
    }

    /// The half-circle as a sampled path, so `trim` fills it left to right.
    private var arc: Path {
        Path { p in
            p.move(to: point(0))
            for i in 1...120 { p.addLine(to: point(Double(i) / 120)) }
        }
    }

    private var ticks: some View {
        Path { p in
            for k in 0...(maxRating * 2) {
                let t = Double(k) / Double(maxRating * 2)
                let whole = k % 2 == 0
                p.move(to: point(t, r: radius + lineWidth / 2 + 5 * scale))
                p.addLine(to: point(t, r: radius + lineWidth / 2 + (whole ? 12 : 8) * scale))
            }
        }
        .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private var knob: some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth + 8 * scale, height: lineWidth + 8 * scale)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .position(point(fraction))
            .opacity(rating > 0 ? 1 : 0)
    }

    private func update(at location: CGPoint) {
        let dx = Double(location.x - center.x), dy = Double(location.y - center.y)
        let t: Double
        if dy > 0 {
            // Below the dial's centre line: pin to whichever end the finger is nearer.
            t = dx < 0 ? 0 : 1
        } else {
            t = (atan2(dy, dx) + Double.pi) / Double.pi
        }
        let value = max(0.1, min(Double(maxRating), (t * Double(maxRating) * 10).rounded() / 10))
        guard value != rating else { return }
        let crossedHalf = Int(value * 2) != Int(rating * 2)
        if crossedHalf { impact.impactOccurred(intensity: 0.5) } else { selection.selectionChanged() }
        withAnimation(.snappy(duration: 0.15)) { rating = value }
    }
}

/// Individual bar in the rating control
/// fillPercentage: 0.0 (empty) ... 1.0 (full), 0.5 (half)
struct SpectrumBar: View {
    let fillPercentage: Double // 0.0...1.0
    let height: CGFloat
    var width: CGFloat = 16
    var accentColor: Color
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background (the empty part) — always full width
            RoundedRectangle(cornerRadius: width * 0.3)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
            
            // The filled part, growing left to right. A full-size bar cut to the fill width,
            // so half a bar keeps the bar's own rounded outline: rounding the half-width
            // shape on its own drew a blob that spilled outside the bar.
            if fillPercentage > 0 {
                RoundedRectangle(cornerRadius: width * 0.3)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * fillPercentage, height: height)
                    }
            }
        }
        .frame(width: width, height: height)
        .shadow(
            color: fillPercentage > 0 ? accentColor.opacity(0.6 * fillPercentage) : .clear,
            radius: fillPercentage > 0 ? 8 : 0
        )
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.3)
                .stroke(
                    fillPercentage > 0 ? accentColor.opacity(0.8) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Rating Label
/// Shows the rating value with optional label
struct RatingLabel: View {
    /// Rating value 0...5 (0.5 steps supported).
    let rating: Double
    let maxRating: Int
    var accentColor: Color = Color.spectrumAccent
    
    var body: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f", rating))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(accentColor)
            
            Text("/ \(maxRating)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// No #Preview here on purpose: it pushed the type-checker's expression complexity over the
// edge, and the production code is kept plain because of it.
