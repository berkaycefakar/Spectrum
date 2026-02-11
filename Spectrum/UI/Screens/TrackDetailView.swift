import SwiftUI
import AVFoundation

/// Track Detail / Song Hub Screen
/// The identity page for each track - like a film page on Letterboxd
struct TrackDetailView: View {
    let track: Track
    
    @State private var showAddLog = false
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var dominantColor: Color = Color(hex: "#FF00FF")
    
    // Mock data for community stats (TODO: Replace with real data from Supabase)
    let communityVibes: [CommunityVibe] = [
        CommunityVibe(color: "#007AFF", percentage: 0.35, label: "Chill"),
        CommunityVibe(color: "#FF2D55", percentage: 0.25, label: "Energetic"),
        CommunityVibe(color: "#5856D6", percentage: 0.20, label: "Melancholic"),
        CommunityVibe(color: "#FFCC00", percentage: 0.12, label: "Happy"),
        CommunityVibe(color: "#4CD964", percentage: 0.08, label: "Focus")
    ]
    
    // Mock friends data (TODO: Replace with real friend activity)
    let friendsWhoVibed: [FriendVibe] = [
        FriendVibe(username: "sarah", avatarUrl: nil),
        FriendVibe(username: "mike", avatarUrl: nil),
        FriendVibe(username: "emma", avatarUrl: nil),
        FriendVibe(username: "alex", avatarUrl: nil)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section
                    heroSection
                    
                    // Content
                    VStack(spacing: 28) {
                        // Community Vibe Section
                        communityVibeSection
                        
                        // Action Bar
                        actionBar
                        
                        // Friends Activity
                        if !friendsWhoVibed.isEmpty {
                            friendsActivitySection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddLog) {
            AddLogView(track: track, isPresented: $showAddLog)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Blurred background
            AsyncImage(url: track.artworkUrl600) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(height: 400)
            .blur(radius: 50)
            .overlay(Color.black.opacity(0.4))
            .clipped()
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(spacing: 20) {
                // Album Art (floating)
                AsyncImage(url: track.artworkUrl600) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: dominantColor.opacity(0.6), radius: 30)
                
                // Track Info
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(track.artist)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Community Vibe Section
    private var communityVibeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Vibe")
                .font(.headline)
                .foregroundStyle(.white)
            
            // Spectrum Bar
            CommunityVibeBar(vibes: communityVibes)
            
            // Stats
            HStack {
                Label("247 logs", systemImage: "doc.text")
                Spacer()
                Label("4.2 avg rating", systemImage: "star.fill")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Log/Review Button
                GlassActionButton(
                    icon: "square.and.pencil",
                    title: "Log",
                    accentColor: Color(hex: "#FF00FF")
                ) {
                    showAddLog = true
                }
                
                // Play Preview Button
                GlassActionButton(
                    icon: isPlaying ? "pause.fill" : "play.fill",
                    title: isPlaying ? "Pause" : "Preview",
                    accentColor: Color(hex: "#00FFFF")
                ) {
                    toggleAudio()
                }
                
                // Share Button
                GlassActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    accentColor: Color(hex: "#FF9500")
                ) {
                    shareTrack()
                }
            }
            // NOTE: iTunes Search API doğrudan "artist entity" döndürmüyor.
            // Artist puanlama özelliğini şimdilik kapattık.
        }
    }
    
    // MARK: - Friends Activity Section
    private var friendsActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends who vibed with this")
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: -10) {
                ForEach(Array(friendsWhoVibed.prefix(5).enumerated()), id: \.offset) { index, friend in
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                        
                        if let avatarUrl = friend.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    initialsView(for: friend.username)
                                }
                            }
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                        } else {
                            initialsView(for: friend.username)
                        }
                    }
                    .zIndex(Double(friendsWhoVibed.count - index))
                }
                
                if friendsWhoVibed.count > 5 {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 46, height: 46)
                        
                        Text("+\(friendsWhoVibed.count - 5)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func initialsView(for username: String) -> some View {
        Text(String(username.prefix(1)).uppercased())
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.white.opacity(0.2))
            .clipShape(Circle())
    }
    
    // MARK: - Audio
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
            player?.play()
            isPlaying = true
        }
    }
    
    private func shareTrack() {
        // TODO: Implement sharing
    }
}

// MARK: - Supporting Models

struct CommunityVibe: Identifiable {
    let id = UUID()
    let color: String
    let percentage: CGFloat
    let label: String
}

struct FriendVibe: Identifiable {
    let id = UUID()
    let username: String
    let avatarUrl: String?
}

// MARK: - Community Vibe Bar Component

struct CommunityVibeBar: View {
    let vibes: [CommunityVibe]
    
    var body: some View {
        VStack(spacing: 12) {
            // The bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(vibes) { vibe in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: vibe.color))
                            .frame(width: max((geometry.size.width * vibe.percentage) - 2, 4))
                            .shadow(color: Color(hex: vibe.color).opacity(0.5), radius: 4)
                    }
                }
            }
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Legend
            HStack(spacing: 16) {
                ForEach(vibes.prefix(4)) { vibe in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: vibe.color))
                            .frame(width: 8, height: 8)
                        
                        Text("\(Int(vibe.percentage * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

// MARK: - Glass Action Button

struct GlassActionButton: View {
    let icon: String
    let title: String
    let accentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(accentColor)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: accentColor.opacity(0.2), radius: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrackDetailView(
            track: Track(
                id: 1488408568,
                title: "Blinding Lights",
                artist: "The Weeknd",
                artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/a4/a04da453-3a4b-851b-5813-2b20aa8024e0/source/100x100bb.jpg",
                previewUrl: nil
            )
        )
    }
}
