import SwiftUI

struct FeedCardView: View {
    let track: Track
    let vibeLabel: String
    var vibeColor: Color? = nil
    var rating: Double? = nil
    var reviewText: String? = nil
    
    @ObservedObject private var audioManager = AudioManager.shared

    private var isPlaying: Bool {
        audioManager.isTrackPlaying(track.id)
    }

    // Dynamic Color State
    @State private var dynamicColor: Color = .gray.opacity(0.3) // Default neutral
    @State private var loadedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            // Top Section: Artwork & Info
            HStack(alignment: .top, spacing: 16) {
                // Artwork
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.black.opacity(0.3)
                            .overlay(ProgressView().tint(.white))
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
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
                    
                    Spacer()
                    
                    // Vibe Pill & Rating
                    HStack(spacing: 8) {
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
            
            // Bottom Section: Play Button
            Button(action: toggleAudio) {
                HStack {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    Text(isPlaying ? "Playing Preview" : "Play Preview")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(dynamicColor.opacity(0.2)) // Tint button with vibe
                        
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ), lineWidth: 1)
                    }
                )
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
            print("Failed to load image: \(error)")
        }
    }
    
    private func toggleAudio() {
        audioManager.toggle(trackId: track.id, previewUrl: track.previewUrl)
    }
}
