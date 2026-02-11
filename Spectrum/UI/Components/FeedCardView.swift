import SwiftUI
import AVFoundation

struct FeedCardView: View {
    let track: Track
    let vibeLabel: String
    var vibeColor: Color? = nil
    var rating: Double? = nil
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    
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
            .frame(height: 100)
            
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
            // Use provided vibeColor if available, otherwise extract from artwork
            if let vibeColor = vibeColor {
                dynamicColor = vibeColor
            } else {
                await loadImageAndColor()
            }
            await loadImage()
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }
    
    private func loadImage() async {
        guard let url = track.artworkUrl600, loadedImage == nil else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = uiImage
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    private func loadImageAndColor() async {
        guard let url = track.artworkUrl600 else { return }
        
        // Check if we already have the image to avoid re-fetching on scroll
        if loadedImage != nil { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = uiImage
                    // Force extraction on main thread to ensure UI update
                    if let avgColor = uiImage.averageColor {
                        withAnimation(.easeIn(duration: 0.3)) {
                            // Boost saturation slightly for neon effect
                            self.dynamicColor = Color(uiColor: avgColor)
                        }
                    }
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    private func toggleAudio() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil, let urlString = track.previewUrl, let url = URL(string: urlString) {
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Audio session error: \(error)")
                }
                player = AVPlayer(url: url)
            }
            
            if let player = player {
                player.play()
                isPlaying = true
                
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                    self.isPlaying = false
                    self.player?.seek(to: .zero)
                }
            }
        }
    }
}
