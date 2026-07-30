import Combine
import SwiftUI
import UIKit

// MARK: - Scroll State

/// Drives the collapsing tab bar.
///
/// The tab screens report their scroll offset here; scrolling *down* drops the labels and
/// shrinks the capsule, scrolling up or coming to a stop brings them back.
///
/// Deliberately a shared singleton observed *inside* `SpectrumTabBar` and nowhere else: when
/// `ContentView` observed it, every collapse re-evaluated the whole `TabView` — all four
/// screens — which is what made the bar feel sluggish.
///
/// The conformance has to be spelled `nonisolated`: the target builds with
/// `InferIsolatedConformances`, which would otherwise make a `final` @MainActor type's
/// ObservableObject conformance actor-isolated — and `@StateObject` needs a nonisolated one.
@MainActor
final class TabBarScrollState: nonisolated ObservableObject {
    static let shared = TabBarScrollState()

    @Published var isCollapsed = false

    /// Only the visible tab drives the bar. Background tabs keep reporting geometry as their
    /// data loads in, which would otherwise collapse the bar out of nowhere.
    private var activeTab = 0

    /// How far the finger has to travel in one direction before the bar reacts. Without it the
    /// bar flickers on the tiny offset jitter a list produces while it settles.
    private let threshold: CGFloat = 12
    /// Scroll deltas below this are layout noise (cell sizing, image loads), not scrolling.
    private let noiseFloor: CGFloat = 0.5
    /// How long the scroll has to be still before the labels come back.
    private let idleDelay: Duration = .milliseconds(250)

    private var lastOffset: CGFloat?
    private var travel: CGFloat = 0
    private var idleTask: Task<Void, Never>?

    private init() {}

    /// `offset` grows as the content moves *down* (i.e. as the user scrolls up).
    func report(offset: CGFloat, from tab: Int) {
        guard tab == activeTab else { return }
        defer { lastOffset = offset }

        guard let last = lastOffset else { return }
        let delta = offset - last
        guard abs(delta) > noiseFloor else { return }

        // Reset the accumulator on a direction change so a flick the other way responds
        // immediately instead of first having to undo the travel already banked.
        travel = (travel.sign == delta.sign) ? travel + delta : delta

        if travel < -threshold {
            setCollapsed(true)
            travel = 0
        } else if travel > threshold {
            setCollapsed(false)
            travel = 0
        }

        scheduleIdleExpand()
    }

    /// The iOS 17 path drives this from a drag gesture, whose translation restarts at zero on
    /// every new drag.
    func scrollEnded(from tab: Int) {
        guard tab == activeTab else { return }
        lastOffset = nil
        travel = 0
        scheduleIdleExpand()
    }

    /// Called when the tab changes: the new screen starts at its own offset, and its labels
    /// should be visible.
    func activate(tab: Int) {
        activeTab = tab
        idleTask?.cancel()
        idleTask = nil
        lastOffset = nil
        travel = 0
        setCollapsed(false)
    }

    private func scheduleIdleExpand() {
        idleTask?.cancel()
        idleTask = Task { [idleDelay] in
            try? await Task.sleep(for: idleDelay)
            guard !Task.isCancelled else { return }
            self.travel = 0
            self.setCollapsed(false)
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard collapsed != isCollapsed else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isCollapsed = collapsed
        }
    }
}

// MARK: - Scroll Reporting

private struct TabBarScrollTracker: ViewModifier {
    let tab: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, y in
                // Flip the sign so it reads like "content position", matching the drag path.
                TabBarScrollState.shared.report(offset: -y, from: tab)
            }
        } else {
            // iOS 17 has no scroll-geometry callback; the drag itself is close enough, and
            // running it simultaneously leaves the scroll view's own gesture untouched.
            content.simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        TabBarScrollState.shared.report(offset: value.translation.height, from: tab)
                    }
                    .onEnded { _ in
                        TabBarScrollState.shared.scrollEnded(from: tab)
                    }
            )
        }
    }
}

extension View {
    /// Attach to a tab screen's `ScrollView` so the tab bar collapses while it is scrolled.
    /// `tab` must match the screen's tag in `ContentView`.
    func tracksTabBarScroll(tab: Int) -> some View {
        modifier(TabBarScrollTracker(tab: tab))
    }
}

// MARK: - Tab Bar

struct SpectrumTabItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

/// Floating glass capsule, sized to match the system tab bar on iOS 26. Scrolling down drops
/// the labels and tightens the capsule; stopping brings them back.
///
/// Only the capsule itself takes touches — the margin around it stays transparent so a drag
/// that starts beside the bar still scrolls the content underneath.
struct SpectrumTabBar: View {
    @Binding var selection: Int

    @StateObject private var scrollState = TabBarScrollState.shared
    @Namespace private var pillNamespace

    /// The highlight follows this, not `selection`, so it moves on the very frame of the tap.
    /// Switching tabs builds the destination screen — on a cold tab that is slow enough that
    /// binding the highlight to `selection` made the bar look frozen for a second or two.
    @State private var pillSelection: Int?
    /// Reused and pre-armed: allocating a generator per tap makes the *first* tap pay for the
    /// haptic engine waking up.
    @State private var haptics = UIImpactFeedbackGenerator(style: .soft)

    private let items: [SpectrumTabItem] = [
        SpectrumTabItem(id: 0, title: "Home", icon: "house.fill"),
        SpectrumTabItem(id: 1, title: "Discover", icon: "magnifyingglass"),
        SpectrumTabItem(id: 2, title: "Activity", icon: "bell.fill"),
        SpectrumTabItem(id: 3, title: "Profile", icon: "person.fill")
    ]

    private var isCollapsed: Bool { scrollState.isCollapsed }
    private var itemHeight: CGFloat { isCollapsed ? 40 : 52 }
    /// Matches the inset the system capsule uses, and pulls in a little when collapsed.
    private var sideInset: CGFloat { isCollapsed ? 46 : 22 }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    select(item.id)
                } label: {
                    tabLabel(for: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(barBackground)
        .padding(.horizontal, sideInset)
        .onAppear {
            pillSelection = selection
            haptics.prepare()
        }
        .onChange(of: selection) { _, newValue in
            // Keeps the highlight honest when the tab changes from somewhere other than a tap.
            if pillSelection != newValue { pillSelection = newValue }
        }
    }

    private func select(_ id: Int) {
        // Tapping the tab you're already on goes back to that tab's root, the way every
        // system tab bar behaves.
        guard selection != id else {
            haptics.impactOccurred()
            haptics.prepare()
            TabReselectionState.shared.requestPopToRoot(tab: id)
            return
        }
        haptics.impactOccurred()
        haptics.prepare()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            pillSelection = id
        }
        // Deferred a runloop turn so the highlight is drawn before SwiftUI starts building the
        // destination screen, instead of both landing in the same (slow) transaction.
        Task { @MainActor in
            selection = id
        }
    }

    private func tabLabel(for item: SpectrumTabItem) -> some View {
        let isSelected = (pillSelection ?? selection) == item.id

        return VStack(spacing: isCollapsed ? 0 : 3) {
            Image(systemName: item.icon)
                .font(.system(size: 19, weight: .semibold))
                .frame(height: 22)

            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .fixedSize()
                .frame(height: isCollapsed ? 0 : 12)
                .opacity(isCollapsed ? 0 : 1)
        }
        .foregroundStyle(isSelected ? Color(hex: "#FF00FF") : Color.white.opacity(0.5))
        .frame(maxWidth: .infinity)
        .frame(height: itemHeight)
        .contentShape(Capsule())
        // The title is driven to zero height and zero opacity when the bar collapses, which
        // drops it out of the accessibility tree — so after any downward scroll all four tabs
        // announced as unlabelled buttons. The label is stated here instead, where collapsing
        // can't reach it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .matchedGeometryEffect(id: "selectedPill", in: pillNamespace)
            }
        }
    }

    /// On iOS 26 this is real Liquid Glass — `interactive()` is what makes it light up and
    /// deform under a finger, the same as the system bar. Older systems fall back to the
    /// material stack the old `UITabBarAppearance` produced.
    @ViewBuilder
    private var barBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Capsule().fill(Color.black.opacity(0.3)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var selection = 0

        var body: some View {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                Button("Toggle collapse") {
                    TabBarScrollState.shared.report(offset: 0, from: 0)
                }
                .foregroundStyle(.white)
                SpectrumTabBar(selection: $selection)
            }
        }
    }
    return PreviewHost()
}
