import SwiftUI
import AVFoundation

struct TrackCardView: View {
    let track: Track
    let vibeColor: Color
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Dynamic Background Glow (The "Vibe")
            vibeColor
                .opacity(0.4)
                .blur(radius: 60)
                .offset(x: 10, y: 10)
            
            // 2. The Glass Card
            VStack(alignment: .leading, spacing: 16) {
                // Artwork
                AsyncImage(url: track.artworkUrl600) { phase in
                    switch phase {
                    case .empty:
                        Color.black.opacity(0.3)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.3)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                
                // Info & Controls
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(.title2, design: .default))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(track.artist)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play Button
                    Button(action: toggleAudio) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(vibeColor.gradient)
                            .shadow(color: vibeColor.opacity(0.5), radius: 10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(.ultraThinMaterial) // Apple's native glass material
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        }
        .frame(width: 320)
        .onDisappear {
            player?.pause()
        }
    }
    
    private func toggleAudio() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil, let urlString = track.previewUrl, let url = URL(string: urlString) {
                player = AVPlayer(url: url)
            }
            player?.play()
            isPlaying = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TrackCardView(
            track: Track(
                id: 1,
                title: "Midnight City",
                artist: "M83",
                artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/9b/6e/81/9b6e8198-315f-5100-3622-261548e69f87/source/100x100bb.jpg",
                previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/3b/6e/81/3b6e8198-315f-5100-3622-261548e69f87/mzaf_123456789.plus.aac.p.m4a"
            ),
            vibeColor: Color(hex: "#FF00FF") // Neon Purple
        )
    }
}
