import SwiftUI

/// Activity & Notifications Screen
/// Shows likes, follows, and other social interactions
struct ActivityView: View {
    @State private var activities: [ActivityItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var filter: ActivityFilter = .all
    @StateObject private var reselection = TabReselectionState.shared
    /// Value-based navigation so tapping Activity while already on it returns to the list.
    @State private var path = NavigationPath()
    /// `.font(.system(size:))` is frozen at whatever number you type — it ignores the
    /// reader's text size entirely. `@ScaledMetric` is the fixed-size equivalent that still
    /// responds to Settings, scaled against the text style this heading stands in for.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 28

    var body: some View {
        NavigationStack(path: $path) {
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
            .appRouteDestinations()
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .task {
                await loadNotifications()
                // Reaching this screen is what "seen" means. Marked after the load so the
                // read marker can't jump ahead of rows the user never actually got.
                ActivityBadgeStore.shared.markSeen()
            }
            // `.task` only runs once per view identity, so the tab showed whatever was true
            // when the app launched — new followers never appeared until a relaunch.
            .refreshable {
                await loadNotifications()
                ActivityBadgeStore.shared.markSeen()
            }
        }
        .onChange(of: reselection.token(for: 2)) { _, _ in
            path = NavigationPath()
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
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
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

    // MARK: - Filter
    private enum ActivityFilter: CaseIterable {
        case all, logs, followers

        var title: String {
            switch self {
            case .all: String(localized: "All", bundle: appStringsBundle)
            case .logs: String(localized: "Logs", bundle: appStringsBundle)
            case .followers: String(localized: "Followers", bundle: appStringsBundle)
            }
        }

        func includes(_ item: ActivityItem) -> Bool {
            switch self {
            case .all: true
            case .logs: item.type != .newFollower
            case .followers: item.type == .newFollower
            }
        }
    }

    private var filteredActivities: [ActivityItem] {
        activities.filter { filter.includes($0) }
    }

    private var followerCount: Int {
        activities.filter { $0.type == .newFollower }.count
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(ActivityFilter.allCases, id: \.self) { option in
                let selected = filter == option
                Button {
                    withAnimation(.snappy(duration: 0.2)) { filter = option }
                } label: {
                    HStack(spacing: 5) {
                        Text(option.title)
                        if option == .followers, followerCount > 0 {
                            Text("\(followerCount)")
                                .foregroundStyle(selected ? Color(hex: "#C800C8") : Color(hex: "#FF4DFF"))
                        }
                    }
                    .font(.subheadline.weight(selected ? .bold : .semibold))
                    .foregroundStyle(selected ? .black : .white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.07)), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(selected ? 0 : 0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Time grouping
    private enum TimeBucket: String, CaseIterable {
        case today
        case week
        case earlier

        /// Separate from the raw value so the section header is translated; the raw value is
        /// only an identity for grouping.
        var title: String {
            switch self {
            case .today: String(localized: "Today", bundle: appStringsBundle)
            case .week: String(localized: "This Week", bundle: appStringsBundle)
            case .earlier: String(localized: "Earlier", bundle: appStringsBundle)
            }
        }
    }

    private func bucket(for date: Date) -> TimeBucket {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return .today }
        if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 { return .week }
        return .earlier
    }

    private var groupedActivities: [(bucket: TimeBucket, items: [ActivityItem])] {
        let grouped = Dictionary(grouping: filteredActivities) { bucket(for: $0.createdAt) }
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
            
            Text("No activity yet")
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
            VStack(alignment: .leading, spacing: 18) {
                header
                filterChips

                if groupedActivities.isEmpty {
                    Text(filter == .followers ? "No new followers yet" : "No logs from people you follow yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }

                ForEach(groupedActivities, id: \.bucket) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.bucket.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.leading, 30)

                        // Rows sit flush so the timeline rail reads as one line through the
                        // group; each row carries its own bottom gap instead.
                        LazyVStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                timelineRow(item, isLast: index == group.items.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .tracksTabBarScroll(tab: 2)
    }

    private func timelineRow(_ item: ActivityItem, isLast: Bool) -> some View {
        let node = item.type == .newFollower
            ? Color(hex: "#0A84FF")
            : Color(hex: item.vibeColor ?? "#FF2D55")
        return HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 20)
                    // The last row's rail would point at nothing.
                    .opacity(isLast ? 0 : 1)
                Circle()
                    .fill(node)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black, lineWidth: 3))
                    .shadow(color: node.opacity(0.7), radius: 5)
                    .padding(.top, 18)
            }
            .frame(width: 18)
            .accessibilityHidden(true)

            // Activity cards render other people's review text, so they need the same
            // Report / Block pair the feed has — Apple checks every surface that displays
            // user content, not just the main one.
            ActivityItemCard(activity: item)
                .moderationActions(
                    contentType: item.reportedContentType,
                    contentRef: item.id.uuidString,
                    authorId: item.actorId,
                    authorUsername: item.actorUsername,
                    reportedText: item.reviewText,
                    onBlocked: { Task { await loadNotifications() } }
                )
                .padding(.bottom, 12)
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
        #if DEBUG
        if DemoMode.isOn {
            activities = DemoData.activity
            isLoading = false
            return
        }
        #endif
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
// `timeAgoDisplay()` lives in Core/Extensions/Date+Display.swift.

// MARK: - Preview

#Preview {
    ActivityView()
}
