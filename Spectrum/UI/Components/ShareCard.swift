import SwiftUI

/// The image behind "share this log".
///
/// A share sheet carrying a link is fine for sending a song to one person, but it is useless
/// as distribution: nothing about it says where it came from. This renders the log as a
/// square card — artwork, rating, the vibe colour, the review — that can be posted to a story
/// and still reads as Spectrum.
///
/// Laid out at a fixed 1080×1080 and rendered off-screen, so it never depends on the device's
/// screen size or the reader's text size. That is also why every measurement here is a raw
/// number rather than a text style: this view is never actually shown to anybody.
struct ShareCard: View {
    let track: Track
    let rating: Int
    let vibeHex: String
    let reviewText: String?
    let username: String?

    /// The rendered edge length. Square because that is what survives every platform's crop.
    static let side: CGFloat = 1080

    private var vibe: Color { Color(hex: vibeHex) }
    private var displayRating: Double { Double(rating) / 2.0 }

    var body: some View {
        ZStack {
            Color.black

            // The vibe, bled into the background the way the app does everywhere else.
            RadialGradient(
                colors: [vibe.opacity(0.55), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: Self.side * 0.9
            )

            VStack(alignment: .leading, spacing: 44) {
                artwork

                VStack(alignment: .leading, spacing: 14) {
                    Text(track.title)
                        .font(.system(size: 62, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    Text(track.artist)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                stars

                if let reviewText, !reviewText.isEmpty {
                    Text("\u{201C}\(ProfanityFilter.masked(reviewText))\u{201D}")
                        .font(.system(size: 34, weight: .regular))
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(72)
        }
        .frame(width: Self.side, height: Self.side)
    }

    private var artwork: some View {
        // `Image(uiImage:)` rather than `AsyncImage`: `ImageRenderer` snapshots synchronously
        // and would capture the placeholder. The caller downloads the artwork first.
        Group {
            if let image = artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                vibe.opacity(0.35)
            }
        }
        .frame(width: 340, height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .stroke(.white.opacity(0.18), lineWidth: 2)
        )
        .shadow(color: vibe.opacity(0.6), radius: 60)
    }

    var artworkImage: UIImage?

    private var stars: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starName(for: index))
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(vibe)
            }

            Text(String(format: "%.1f", displayRating))
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.leading, 8)
        }
    }

    /// Matches the half-star logic the log page uses, so the card can't disagree with the app.
    private func starName(for index: Int) -> String {
        if Double(index) <= displayRating { return "star.fill" }
        if Double(index) - 0.5 <= displayRating { return "star.leadinghalf.filled" }
        return "star"
    }

    private var footer: some View {
        HStack(spacing: 16) {
            SpectrumMark(size: 52)

            VStack(alignment: .leading, spacing: 0) {
                Text("Spectrum")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                if let username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            Circle()
                .fill(vibe)
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 2))
        }
    }
}

// MARK: - Rendering

enum ShareCardRenderer {

    /// Renders the card to a PNG-backed `UIImage`, downloading the artwork first.
    ///
    /// `@MainActor` because `ImageRenderer` walks a SwiftUI view tree. The scale is pinned to
    /// 1 — the card is already laid out at 1080pt, so letting it pick up a 3× device scale
    /// would produce a 3240px image for no visible gain.
    @MainActor
    static func render(
        track: Track,
        rating: Int,
        vibeHex: String,
        reviewText: String?,
        username: String?
    ) async -> UIImage? {
        let artwork = await downloadArtwork(from: track.artworkUrl600)

        let card = ShareCard(
            track: track,
            rating: rating,
            vibeHex: vibeHex,
            reviewText: reviewText,
            username: username,
            artworkImage: artwork
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private static func downloadArtwork(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            // The card still works without it — the vibe colour fills the square instead.
            debugLog("Share card: couldn't load artwork:", error)
            return nil
        }
    }
}

// MARK: - Presentation helpers

/// Wraps the rendered card so it can drive a `.sheet(item:)`.
///
/// `UIImage` isn't `Identifiable`, and the identity has to change every time a new card is
/// built — otherwise re-sharing the same log after an edit re-presents the stale image.
struct ShareCardImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// `UIActivityViewController` in SwiftUI clothing.
///
/// `ShareLink` can carry a `Transferable`, but wrapping a freshly rendered `UIImage` in one
/// costs a custom `Transferable` conformance for no gain — this is presented from a sheet,
/// which is exactly the lifecycle a representable handles correctly.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
