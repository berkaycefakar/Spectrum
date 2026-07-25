import SwiftUI
import UIKit

// MARK: - Vibe Palette

/// The eight vibes the prism offers, and the names we show for them.
///
/// This lives outside `AddLogView`/`SpectrumPrismPicker` because community summaries have to
/// name colours *other people* saved — including artwork-derived hexes (artist ratings) that
/// aren't exact palette entries. Those get snapped to the nearest palette bucket so a page
/// can say "mostly Chill" instead of listing eight near-identical blues.
enum VibePalette {
    static let colors: [String] = [
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#4CD964", // Green
        "#5AC8FA", // Light Blue
        "#007AFF", // Blue
        "#5856D6", // Purple
        "#FF2D55"  // Pink
    ]

    static func label(for hex: String) -> String {
        switch snap(hex) {
        case "#FF3B30": return "Energetic"
        case "#FF9500": return "Warm"
        case "#FFCC00": return "Sunny"
        case "#4CD964": return "Fresh"
        case "#5AC8FA": return "Chill"
        case "#007AFF": return "Deep"
        case "#5856D6": return "Dreamy"
        case "#FF2D55": return "Passionate"
        default: return "Vibe"
        }
    }

    /// Palette entry closest to `hex`, or `hex` itself when it already is one.
    static func snap(_ hex: String) -> String {
        let normalized = hex.uppercased()
        if colors.contains(normalized) { return normalized }
        return nearest(to: Color(hex: hex))
    }

    /// Nearest palette entry to `color`, matched primarily on hue. RGB distance picks oddly —
    /// a pale colour is close to *everything* in RGB space.
    static func nearest(to color: Color) -> String {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        var nearestColor = colors[0]
        var minDistance = CGFloat.greatestFiniteMagnitude

        for hex in colors {
            var pHue: CGFloat = 0, pSat: CGFloat = 0, pBright: CGFloat = 0, pAlpha: CGFloat = 0
            UIColor(Color(hex: hex)).getHue(&pHue, saturation: &pSat, brightness: &pBright, alpha: &pAlpha)

            // Hue is circular: red at 0.02 and red at 0.98 are neighbours, not opposites.
            let rawDelta = abs(hue - pHue)
            let hueDelta = min(rawDelta, 1 - rawDelta)

            // Hue dominates; saturation breaks ties between similar hues.
            let distance = hueDelta * 3 + abs(saturation - pSat) * 0.5

            if distance < minDistance {
                minDistance = distance
                nearestColor = hex
            }
        }

        return nearestColor
    }
}

// MARK: - Community Stats

/// One palette bucket's share of a page's logs.
struct VibeShare: Identifiable {
    let hex: String
    let count: Int
    let share: CGFloat

    var id: String { hex }
    var label: String { VibePalette.label(for: hex) }
    var percentText: String { "\(Int((share * 100).rounded()))%" }
}

/// Aggregate of everything the community logged for one track / album / artist.
struct CommunityStats {
    let count: Int
    /// 0...5, averaged from the 0...10 integers we store.
    let averageRating: Double
    /// Palette buckets, most-picked first.
    let vibes: [VibeShare]

    var topVibe: VibeShare? { vibes.first }
    var isEmpty: Bool { count == 0 }

    init(ratings: [Int], vibeHexes: [String]) {
        count = ratings.count
        averageRating = ratings.isEmpty
            ? 0
            : Double(ratings.reduce(0, +)) / Double(ratings.count) / 2.0

        var buckets: [String: Int] = [:]
        for hex in vibeHexes {
            buckets[VibePalette.snap(hex), default: 0] += 1
        }

        let total = CGFloat(max(vibeHexes.count, 1))
        vibes = buckets
            // Ties resolve by hex so the order doesn't flicker between loads.
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { VibeShare(hex: $0.key, count: $0.value, share: CGFloat($0.value) / total) }
    }

    static let empty = CommunityStats(ratings: [], vibeHexes: [])
}

// MARK: - Community Stats Card

/// "What did everyone else think?" — average score, how many people scored it, and which
/// vibe they picked most. Shared by the track, album and artist pages.
struct CommunityStatsCard: View {
    let stats: CommunityStats
    /// Plural noun for the count column: "logs" on tracks, "ratings" elsewhere.
    var countLabel: String = "ratings"
    var title: String? = "Community"
    var emptyMessage: String = "No ratings yet — be the first!"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if stats.isEmpty {
                emptyState
            } else {
                content
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.25))
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var content: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                averageColumn
                columnDivider
                countColumn
                if let topVibe = stats.topVibe {
                    columnDivider
                    topVibeColumn(topVibe)
                }
            }

            // Only worth drawing once people actually disagree.
            if stats.vibes.count > 1 {
                vibeBreakdownBar
            }
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var averageColumn: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#FFCC00"))
                Text(String(format: "%.1f", stats.averageRating))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            Text("avg rating")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var countColumn: some View {
        VStack(spacing: 6) {
            Text("\(stats.count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(countLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func topVibeColumn(_ vibe: VibeShare) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: vibe.hex))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color(hex: vibe.hex).opacity(0.8), radius: 5)
                Text(vibe.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text("top vibe · \(vibe.percentText)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 1, height: 36)
    }

    private var vibeBreakdownBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(stats.vibes) { vibe in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: vibe.hex))
                        // Floor so a single-log bucket stays visible on a busy page.
                        .frame(width: max(geo.size.width * vibe.share - 2, 4))
                        .shadow(color: Color(hex: vibe.hex).opacity(0.5), radius: 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 10)
        .background(
            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            CommunityStatsCard(
                stats: CommunityStats(
                    ratings: [9, 8, 10, 7, 9],
                    vibeHexes: ["#5AC8FA", "#5AC8FA", "#5856D6", "#5AC8FA", "#FF9500"]
                ),
                countLabel: "logs"
            )
            CommunityStatsCard(stats: .empty)
        }
        .padding()
    }
}
