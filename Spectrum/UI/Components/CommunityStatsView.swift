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
        case "#FF3B30": return String(localized: "Energetic", bundle: appStringsBundle)
        case "#FF9500": return String(localized: "Warm", bundle: appStringsBundle)
        case "#FFCC00": return String(localized: "Sunny", bundle: appStringsBundle)
        case "#4CD964": return String(localized: "Fresh", bundle: appStringsBundle)
        case "#5AC8FA": return String(localized: "Chill", bundle: appStringsBundle)
        case "#007AFF": return String(localized: "Deep", bundle: appStringsBundle)
        case "#5856D6": return String(localized: "Dreamy", bundle: appStringsBundle)
        case "#FF2D55": return String(localized: "Passionate", bundle: appStringsBundle)
        default: return String(localized: "Vibe", bundle: appStringsBundle)
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

    /// How many logs landed on each whole star, index 0 = 1 star … 4 = 5 stars. Half stars
    /// round up (3.5 counts as 4), the way the App Store groups them.
    let starCounts: [Int]

    var topVibe: VibeShare? { vibes.first }
    var isEmpty: Bool { count == 0 }

    init(ratings: [Int], vibeHexes: [String]) {
        count = ratings.count
        var stars = [0, 0, 0, 0, 0]
        for r in ratings { stars[min(max((r + 1) / 2, 1), 5) - 1] += 1 }
        starCounts = stars
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

/// "What did everyone else think?" Laid out like the App Store's ratings: the average large
/// on the left, how the scores spread over one to five stars on the right, and underneath
/// the colours people heard in it. Shared by the track, album and artist pages.
///
/// Colours have no names here on purpose: the picker doesn't name them either, so a word
/// like "Passionate" would be the app putting a label on someone else's pick.
struct CommunityStatsCard: View {
    let stats: CommunityStats
    /// Plural noun for the count line: "logs" on tracks, "ratings" elsewhere.
    var countLabel: String = String(localized: "ratings", bundle: appStringsBundle)
    /// The same noun for exactly one: "log", "rating".
    var countLabelSingular: String = String(localized: "rating", bundle: appStringsBundle)
    var title: String? = String(localized: "Community", bundle: appStringsBundle)
    var emptyMessage: String = String(localized: "No ratings yet — be the first!", bundle: appStringsBundle)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            if stats.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 20) {
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", stats.averageRating))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("out of 5", bundle: appStringsBundle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .fixedSize()

                VStack(alignment: .trailing, spacing: 4) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        distributionRow(star)
                    }
                    Text("\(stats.count) \(stats.count == 1 ? countLabelSingular : countLabel)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 4)
                }
            }

            vibeBar
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Average \(String(format: "%.1f", stats.averageRating)) out of 5, \(stats.count) \(countLabel)"))
    }

    private func distributionRow(_ star: Int) -> some View {
        let maxCount = max(stats.starCounts.max() ?? 1, 1)
        let share = CGFloat(stats.starCounts[star - 1]) / CGFloat(maxCount)
        return HStack(spacing: 8) {
            HStack(spacing: 1) {
                ForEach(0..<star, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: 7))
                }
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 44, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(.white.opacity(0.75))
                        .frame(width: stats.starCounts[star - 1] == 0 ? 0 : max(geo.size.width * share, 4))
                }
            }
            .frame(height: 4)
        }
    }

    /// Every colour people picked, as one strip split by share.
    private var vibeBar: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(stats.vibes.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(stats.vibes) { vibe in
                    Color(hex: vibe.hex)
                        .frame(width: max((geo.size.width - gaps) * vibe.share, 4))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityHidden(true)
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
