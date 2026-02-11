import SwiftUI

/// Activity & Notifications Screen
/// Shows likes, follows, and other social interactions
struct ActivityView: View {
    // Mock notifications data (TODO: Replace with real backend data)
    @State private var notifications: [ActivityNotification] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Subtle ambient glow
                Circle()
                    .fill(Color(hex: "#FF00FF").opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: 150, y: -200)
                
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .task {
                await loadNotifications()
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Activity Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("When people interact with your logs,\nyou'll see it here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Notifications List
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notifications) { notification in
                    NotificationCard(notification: notification)
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Data Loading
    private func loadNotifications() async {
        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Mock data - TODO: Replace with actual Supabase notifications query
        await MainActor.run {
            notifications = [
                ActivityNotification(
                    type: .like,
                    username: "sarah_music",
                    avatarUrl: nil,
                    message: "liked your review of",
                    trackTitle: "Blinding Lights",
                    timestamp: Date().addingTimeInterval(-3600),
                    isRead: false
                ),
                ActivityNotification(
                    type: .follow,
                    username: "dj_beats",
                    avatarUrl: nil,
                    message: "started following you",
                    trackTitle: nil,
                    timestamp: Date().addingTimeInterval(-7200),
                    isRead: false
                ),
                ActivityNotification(
                    type: .like,
                    username: "vinyl_collector",
                    avatarUrl: nil,
                    message: "liked your review of",
                    trackTitle: "Starboy",
                    timestamp: Date().addingTimeInterval(-86400),
                    isRead: true
                ),
                ActivityNotification(
                    type: .comment,
                    username: "music_nerd",
                    avatarUrl: nil,
                    message: "commented on your review of",
                    trackTitle: "Get Lucky",
                    timestamp: Date().addingTimeInterval(-172800),
                    isRead: true
                ),
                ActivityNotification(
                    type: .follow,
                    username: "indie_fan",
                    avatarUrl: nil,
                    message: "started following you",
                    trackTitle: nil,
                    timestamp: Date().addingTimeInterval(-259200),
                    isRead: true
                )
            ]
            isLoading = false
        }
    }
}

// MARK: - Notification Model

struct ActivityNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let username: String
    let avatarUrl: String?
    let message: String
    let trackTitle: String?
    let timestamp: Date
    let isRead: Bool
    
    enum NotificationType {
        case like
        case follow
        case comment
        
        var icon: String {
            switch self {
            case .like: return "heart.fill"
            case .follow: return "person.badge.plus"
            case .comment: return "bubble.left.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .like: return Color(hex: "#FF2D55")
            case .follow: return Color(hex: "#00FFFF")
            case .comment: return Color(hex: "#FF9500")
            }
        }
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: ActivityNotification
    
    var body: some View {
        HStack(spacing: 14) {
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(notification.type.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: notification.type.color.opacity(0.8), radius: 4)
            } else {
                Spacer().frame(width: 8)
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(notification.type.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                if let avatarUrl = notification.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(notification.type.color)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(notification.username)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text(notification.message)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if let track = notification.trackTitle {
                        Text("'\(track)'")
                            .fontWeight(.medium)
                            .foregroundStyle(notification.type.color)
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
                
                Text(notification.timestamp.timeAgoDisplay())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Follow back button (for follow notifications)
            if notification.type == .follow {
                Button {
                    // TODO: Implement follow back
                } label: {
                    Text("Follow")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    // Glowing left border for unread
                    HStack {
                        if !notification.isRead {
                            Rectangle()
                                .fill(notification.type.color)
                                .frame(width: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: notification.type.color.opacity(0.6), radius: 4)
                        }
                        Spacer()
                    }
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Date Extension for Time Ago

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}
