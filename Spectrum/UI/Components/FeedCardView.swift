import SwiftUI

struct FeedCardView: View {
    let track: Track
    let vibeLabel: String
    var vibeColor: Color? = nil
    var rating: Double? = nil
    var reviewText: String? = nil
    /// Like state and toggle, supplied by the screen. Nil hides the control entirely — used
    /// for previews and for surfaces that aren't a feed of other people's logs.
    var likeState: LikeState? = nil
    var onToggleLike: (() -> Void)? = nil
    /// Opens the author's profile from the name pill. Nil leaves the pill as plain text.
    var onTapAuthor: (() -> Void)? = nil
    /// Comments under this log. Shown only when there are some.
    var commentCount: Int = 0
    /// Opens the song from the artwork, title or artist. The rest of the card opens the log.
    var onTapTrack: (() -> Void)? = nil
    
    @ObservedObject private var audioManager = AudioManager.shared

    private var isPlaying: Bool {
        audioManager.isTrackPlaying(track.id)
    }

    // Dynamic Color State
    @State private var dynamicColor: Color = .gray.opacity(0.3) // Default neutral
    @State private var loadedImage: UIImage?
    
    private var namePill: some View {
        Text(vibeLabel)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((vibeColor ?? dynamicColor).opacity(0.5))
                    .overlay(
                        Capsule()
                            .strokeBorder(vibeColor ?? dynamicColor, lineWidth: 1)
                    )
            )
            .shadow(color: (vibeColor ?? dynamicColor).opacity(0.6), radius: 8)
    }

    /// Makes the artwork and the title a link to the song when `onTapTrack` is set.
    @ViewBuilder
    private func trackTarget<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let onTapTrack {
            Button(action: onTapTrack) { content() }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the song", bundle: appStringsBundle))
        } else {
            content()
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Top Section: Artwork & Info
            HStack(alignment: .top, spacing: 16) {
                // Artwork
                trackTarget {
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.08)
                            .shimmering()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    trackTarget {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.artist)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(track.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Vibe Pill & Rating
                    HStack(spacing: 8) {
                        if let onTapAuthor {
                            Button(action: onTapAuthor) { namePill }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens their profile")
                        } else {
                            namePill
                        }
                        
                        if let rating = rating, rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle((vibeColor ?? dynamicColor))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 100)
            
            // Review text
            if let reviewText = reviewText, !reviewText.isEmpty {
                Text("\"\(reviewText)\"")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Bottom Section: Play Button, with the like beside it.
            HStack(spacing: 10) {
            Button(action: toggleAudio) {
                previewButtonLabel
            }
            .buttonStyle(PreviewPressStyle())

                if commentCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(commentCount)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(.white.opacity(0.08), in: Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(commentCount) comments", bundle: appStringsBundle))
                }
                if let likeState {
                    LikeButton(state: likeState, onToggle: onToggleLike)
                }
            }
        }
        .padding(20)
        // THE LIQUID GLASS EFFECT (More Prominent)
        .background(
            ZStack {
                // 1. The Blur Material
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // 2. Stronger Dynamic Gradient
                LinearGradient(
                    colors: [dynamicColor.opacity(0.5), .clear], // Increased opacity
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 3. Surface Shine
                LinearGradient(
                    colors: [.white.opacity(0.15), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [dynamicColor.opacity(0.6), .white.opacity(0.1)], // Border matches vibe
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        // Stronger Outer Glow
        .shadow(color: dynamicColor.opacity(0.4), radius: 25, x: 0, y: 10)
        .task {
            await loadImageAndColor()
        }
    }
    
    private func loadImageAndColor() async {
        guard let url = track.artworkUrl600 else { return }
        
        // Check if we already have the image to avoid re-fetching on scroll
        if loadedImage != nil { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }

            await MainActor.run { self.loadedImage = uiImage }
            launchTrace("card artwork: \(track.title)")

            // Extract the dominant colour off the main thread — doing this inline on the main
            // actor for every visible feed card was locking up the UI. The shared loader runs
            // it on a background executor and caches the result.
            let artworkColor = await ArtworkColorLoader.shared.color(for: url)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    self.dynamicColor = artworkColor.accent
                }
            }
        } catch {
            debugLog("Failed to load image: \(error)")
        }
    }
    
    // MARK: - Preview button

    private var isBuffering: Bool { audioManager.isTrackBuffering(track.id) }
    private var isLoaded: Bool { audioManager.isTrackLoaded(track.id) }

    /// One fixed layout for all three states (idle, loading, playing): the icon swaps in a
    /// fixed slot and the label cross-fades, so the button never changes size or jumps.
    /// While this track is loaded, the button fills left to right with the preview's progress.
    private var previewButtonLabel: some View {
        HStack(spacing: 8) {
            ZStack {
                if isBuffering {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                } else {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .frame(width: 18, height: 18)

            ZStack {
                if isBuffering {
                    Text("Loading...")
                        .transition(.opacity.combined(with: .offset(y: 6)))
                } else if isPlaying {
                    Text("Playing Preview")
                        .transition(.opacity.combined(with: .offset(y: 6)))
                } else {
                    Text("Play Preview")
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }
            }
        }
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(dynamicColor.opacity(isPlaying ? 0.32 : 0.2))

                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [dynamicColor.opacity(0.55), .white.opacity(0.22)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * (isLoaded ? audioManager.progress : 0))
                        // Matches the player's four ticks a second, so the fill glides.
                        .animation(.linear(duration: 0.25), value: audioManager.progress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(isLoaded ? 1 : 0)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(isPlaying ? 0.45 : 0.3), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ), lineWidth: 1)
            }
        }
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .animation(.smooth(duration: 0.3), value: isBuffering)
        .animation(.smooth(duration: 0.3), value: isLoaded)
    }

    private func toggleAudio() {
        audioManager.toggle(track: track)
    }
}

/// A light press: the button dips slightly while held.
private struct PreviewPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
