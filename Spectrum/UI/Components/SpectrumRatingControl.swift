import SwiftUI
import UIKit

/// Custom on-brand rating control using vertical glowing bars.
/// - Rates in half-steps (3.5, say).
/// - Each bar is taller than the one before it, left to right; the fifth is the tallest.
struct SpectrumRatingControl: View {
    /// Rating value in the range 0...5 (0.5 steps).
    @Binding var rating: Double
    var accentColor: Color = Color(hex: "#FF00FF")
    /// Maximum display rating (5 = 5 bars).
    var maxRating: Int = 5
    
    // Heights for the bars - progressively increasing left to right.
    // The first bar is the shortest, the fifth the tallest.
    private let barHeights: [CGFloat] = [22, 28, 34, 40, 46]
    
    // Haptic feedback generator - sadece bir kez initialize et
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .soft)
    @State private var lastHapticRating: Double = -1 // The rating we last buzzed on
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                Spacer()
                ForEach(1...maxRating, id: \.self) { index in
                    SpectrumBar(
                        fillPercentage: calculateFillPercentage(for: index),
                        height: barHeights[index - 1],
                        accentColor: accentColor
                    )
                    .onTapGesture {
                        hapticGenerator.impactOccurred(intensity: 0.7)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            rating = Double(index)
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle()) // Tüm alan drag için aktif
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let totalWidth = geometry.size.width
                        let x = max(0, min(value.location.x, totalWidth))
                        let raw = Double(x / totalWidth) * Double(maxRating) // 0...5
                        let stepped = (raw * 2).rounded() / 2              // half-steps
                        let clamped = max(0, min(Double(maxRating), stepped))
                        if clamped != rating {
                            // Haptics only when the drag crosses a half-step
                            let currentStep = Int(clamped * 2)
                            let lastStep = Int(lastHapticRating * 2)
                            if currentStep != lastStep {
                                hapticGenerator.impactOccurred(intensity: 0.5)
                                lastHapticRating = clamped
                            }
                            
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                rating = clamped
                            }
                        }
                    }
                    .onEnded { _ in
                        // One last buzz when the drag ends
                        hapticGenerator.impactOccurred(intensity: 0.6)
                    }
            )
        }
        .frame(height: 60)
        .padding(.vertical, 8)
        .onAppear {
            hapticGenerator.prepare()
        }
    }
    
    /// Her bar için fill percentage hesapla (0.0...1.0)
    /// A rating of 2.5 gives bar 1: 1.0, bar 2: 1.0, bar 3: 0.5, bar 4: 0.0, bar 5: 0.0
    private func calculateFillPercentage(for index: Int) -> Double {
        let barStart = Double(index - 1)
        let barEnd = Double(index)
        if rating >= barEnd {
            return 1.0 // Tam dolu
        } else if rating > barStart {
            return rating - barStart // Partly filled (2.5 - 2.0 = 0.5)
        } else {
            return 0.0 // Empty
        }
    }
}

/// Individual bar in the rating control
/// fillPercentage: 0.0 (empty) ... 1.0 (full), 0.5 (half)
struct SpectrumBar: View {
    let fillPercentage: Double // 0.0...1.0
    let height: CGFloat
    var accentColor: Color
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background (the empty part) — always full width
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: height)
            
            // The filled part, growing left to right
            if fillPercentage > 0 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 16 * fillPercentage, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: 16, height: height)
        .shadow(
            color: fillPercentage > 0 ? accentColor.opacity(0.6 * fillPercentage) : .clear,
            radius: fillPercentage > 0 ? 8 : 0
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    fillPercentage > 0 ? accentColor.opacity(0.8) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
        .scaleEffect(fillPercentage > 0 ? 1.05 : 1.0)
    }
}

// MARK: - Rating Label
/// Shows the rating value with optional label
struct RatingLabel: View {
    /// Rating value 0...5 (0.5 steps supported).
    let rating: Double
    let maxRating: Int
    var accentColor: Color = Color(hex: "#FF00FF")
    
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
