import SwiftUI

/// The small facts Apple already knows about a record: whether it's explicit, whether it's
/// mixed in Atmos, whether it streams lossless.
///
/// Every value here arrived with the `MusicKit.Album` the page was already fetching — they
/// cost nothing extra, and they are most of what separates a page that looks like a database
/// row from one that looks like a music app.
struct CatalogBadgeRow: View {
    var isExplicit: Bool?
    var audioBadges: [AudioBadge] = []
    /// Drawn in the artwork's accent colour so the row belongs to the page it's on.
    var tint: Color = .white

    private var hasContent: Bool {
        isExplicit == true || !audioBadges.isEmpty
    }

    var body: some View {
        if hasContent {
            // Wraps rather than scrolls: three chips fit on an iPhone SE, and a horizontal
            // scroll view this short reads as broken.
            FlowLayout(spacing: 6) {
                if isExplicit == true {
                    BadgeChip(
                        text: "E",
                        // Apple's own marking is a filled square with an E, not a word.
                        systemImage: nil,
                        tint: .white.opacity(0.75),
                        // Square so it doesn't read as a genre pill.
                        isSquare: true
                    )
                    .accessibilityLabel("Explicit")
                }

                ForEach(audioBadges, id: \.self) { badge in
                    BadgeChip(text: badge.label, systemImage: badge.icon, tint: tint)
                }
            }
        }
    }
}

/// One chip. Kept private: these only make sense together in a `CatalogBadgeRow`.
private struct BadgeChip: View {
    let text: String
    var systemImage: String?
    let tint: Color
    var isSquare = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, isSquare ? 5 : 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: shape)
        .overlay(shape.stroke(tint.opacity(0.28), lineWidth: 1))
    }

    private var shape: AnyShape {
        isSquare ? AnyShape(RoundedRectangle(cornerRadius: 4)) : AnyShape(Capsule())
    }
}
