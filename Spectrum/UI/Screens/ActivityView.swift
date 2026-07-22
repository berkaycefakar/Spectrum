import SwiftUI

/// Activity & Notifications Screen
/// Shows likes, follows, and other social interactions
struct ActivityView: View {
    @State private var activities: [ActivityItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
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
                
                if let errorMessage {
                    errorState(message: errorMessage)
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if activities.isEmpty {
                    emptyState
                } else {
                    activityList
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
    
    // MARK: - Activity List
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(activities) { item in
                    ActivityItemCard(activity: item)
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Error State
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.yellow.opacity(0.8))
            
            Text("Activity Error")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Data Loading
    private func loadNotifications() async {
        do {
            let items = try await SupabaseManager.shared.fetchActivityFeed()
            await MainActor.run {
                self.activities = items
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
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
