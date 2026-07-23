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
                    .fill(Color(hex: "#9652FF").opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 110)
                    .offset(x: 150, y: -240)

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
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .task {
                await loadNotifications()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "#9652FF"), Color(hex: "#5AC8FA")],
                                   startPoint: .top, endPoint: .bottom)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text("Activity")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Reactions and new followers")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Time grouping
    private enum TimeBucket: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case earlier = "Earlier"
    }

    private func bucket(for date: Date) -> TimeBucket {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 { return .week }
        return .earlier
    }

    private var groupedActivities: [(bucket: TimeBucket, items: [ActivityItem])] {
        let grouped = Dictionary(grouping: activities) { bucket(for: $0.createdAt) }
        return TimeBucket.allCases.compactMap { b in
            guard let items = grouped[b], !items.isEmpty else { return nil }
            return (b, items)
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
            VStack(alignment: .leading, spacing: 22) {
                header

                ForEach(groupedActivities, id: \.bucket) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.bucket.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 4)

                        LazyVStack(spacing: 12) {
                            ForEach(group.items) { item in
                                ActivityItemCard(activity: item)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 12)
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
