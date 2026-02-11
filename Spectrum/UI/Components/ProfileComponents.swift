import SwiftUI

// MARK: - Profile Header
/// Displays user avatar, username, bio, and stats in a glassmorphism style
struct ProfileHeader: View {
    let profile: Profile
    let totalLogs: Int
    let averageRating: Double
    let onEditTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF00FF"), Color(hex: "#00FFFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                
                if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .shadow(color: Color(hex: "#FF00FF").opacity(0.5), radius: 20)
            
            // Username & Bio
            VStack(spacing: 8) {
                Text(profile.username ?? "Anonymous")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            // Stats Row
            HStack(spacing: 40) {
                ProfileStatItem(value: "\(totalLogs)", label: "Logs")
                ProfileStatItem(value: String(format: "%.1f", averageRating), label: "Avg Rating")
                // TODO: Wire real followers/following from backend
                ProfileStatItem(value: "0", label: "Followers")
            }
            .padding(.top, 8)
            
            // Edit Button
            Button(action: onEditTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Stat Item
/// Individual stat display (e.g., "12 Logs")
struct ProfileStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Profile Action Button
/// Reusable button for profile actions (Edit, Logout, etc.)
struct ProfileActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        color: Color = .white,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isDestructive ? .red : color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundStyle(isDestructive ? .red : .white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isDestructive ? Color.red.opacity(0.3) : .white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Account Actions Section
/// Section containing profile-related actions like Edit Profile, Settings, Logout
struct AccountActionsSection: View {
    let onEditProfile: () -> Void
    let onLogout: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ProfileActionButton(
                    title: "Edit Profile",
                    icon: "person.crop.circle",
                    color: Color(hex: "#00FFFF"),
                    action: onEditProfile
                )
                
                ProfileActionButton(
                    title: "Settings",
                    icon: "gearshape.fill",
                    color: .white,
                    action: {
                        // TODO: Navigate to settings
                    }
                )
                
                ProfileActionButton(
                    title: "Log Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: onLogout
                )
            }
        }
    }
}

// MARK: - Spectrum Bar Chart
/// Horizontal bar chart showing vibe color distribution
struct SpectrumBarChart: View {
    let stats: [(color: String, percentage: CGFloat, label: String)]
    
    var body: some View {
        VStack(spacing: 12) {
            // The Spectrum Bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: stat.color))
                            .frame(width: max(geometry.size.width * stat.percentage - 2, 4))
                            .shadow(color: Color(hex: stat.color).opacity(0.5), radius: 4)
                    }
                }
            }
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Legend
            HStack(spacing: 16) {
                ForEach(Array(stats.prefix(4).enumerated()), id: \.offset) { index, stat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: stat.color))
                            .frame(width: 8, height: 8)
                        
                        Text("\(Int(stat.percentage * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Album Grid Item
/// Displays a track's artwork in a grid with vibe color glow
struct AlbumGridItem: View {
    let track: Track
    let vibeColor: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // Artwork with glow
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(vibeColor.opacity(0.3))
                    .blur(radius: 20)
                    .offset(y: 10)
                
                AsyncImage(url: track.artworkUrl600) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Color.gray.opacity(0.3)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.5))
                            )
                    } else {
                        Color.gray.opacity(0.3)
                            .overlay(ProgressView().tint(.white))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [vibeColor.opacity(0.6), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
            
            // Track info
            VStack(spacing: 2) {
                Text(track.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(width: 160)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 30) {
                ProfileHeader(
                    profile: Profile(id: UUID(), username: "berkay", avatarUrl: nil, bio: "Music lover"),
                    totalLogs: 42,
                    averageRating: 4.2,
                    onEditTapped: {}
                )
                
                SpectrumBarChart(stats: [
                    (color: "#FF3B30", percentage: 0.4, label: ""),
                    (color: "#007AFF", percentage: 0.3, label: ""),
                    (color: "#5856D6", percentage: 0.2, label: ""),
                    (color: "#FFCC00", percentage: 0.1, label: "")
                ])
                .padding(.horizontal)
                
                AlbumGridItem(
                    track: Track(id: 1, title: "Blinding Lights", artist: "The Weeknd", artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/a4/a04da453-3a4b-851b-5813-2b20aa8024e0/source/100x100bb.jpg", previewUrl: nil),
                    vibeColor: Color(hex: "#FF00FF")
                )
                
                AccountActionsSection(
                    onEditProfile: {},
                    onLogout: {}
                )
                .padding(.horizontal)
            }
        }
    }
}
