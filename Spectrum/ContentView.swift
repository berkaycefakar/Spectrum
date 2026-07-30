import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var musicAuth = MusicAuthorizationStore.shared
    @State private var selectedTab = 0
    @State private var showAuthView = false
    
    init() {
        // Customize Tab Bar Appearance for Glassmorphism.
        // Kept for the system bar — `SpectrumTabBar` currently stands in for it, but this is
        // what the bar looks like the moment the custom one is taken back out.
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Glass Effect Background
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // Item Colors
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.5)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        
        itemAppearance.selected.iconColor = UIColor(Color(hex: "#FF00FF"))
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#FF00FF"))]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        Group {
            if sessionStore.isLoading {
                // Branded splash while the session is being restored.
                SplashView()
            } else if sessionStore.isAuthenticated {
                // User is logged in - show main app
                mainTabView
            } else {
                // User is not logged in - show welcome/auth flow
                if showAuthView {
                    AuthView(isAuthenticated: .constant(false), onSuccess: {
                        // After successful auth, SessionStore is already updated
                        showAuthView = false
                    })
                } else {
                    LandingView(onGetStarted: {
                        showAuthView = true
                    })
                }
            }
        }
        // Every screen paints its own black background, so a light-mode device rendered
        // system alerts, action sheets and the photo picker light-on-black.
        .preferredColorScheme(.dark)
        .task {
            await sessionStore.checkSession()
        }
        .fullScreenCover(isPresented: musicAccessBinding) {
            MusicAccessView {
                musicAuth.hasDismissedExplainer = true
            }
        }
        // Sits above everything, signed in or not: the reset link has already established a
        // session, so this has to be the thing the user lands on.
        .fullScreenCover(isPresented: $sessionStore.isPasswordRecovery) {
            NewPasswordView(mode: .recovery) {
                sessionStore.endPasswordRecovery()
            }
        }
    }

    /// Only worth interrupting a signed-in user — the landing and auth screens work fine
    /// without catalog access.
    private var musicAccessBinding: Binding<Bool> {
        Binding(
            get: { sessionStore.isAuthenticated && musicAuth.shouldShowExplainer },
            set: { isPresented in
                if !isPresented { musicAuth.hasDismissedExplainer = true }
            }
        )
    }
    
    // MARK: - Main Tab View
    /// The system bar is hidden and `SpectrumTabBar` stands in for it: the system one can't
    /// drop its labels or shrink on scroll. Note the scroll state is observed inside the bar,
    /// not here — observing it at this level rebuilt all four screens on every collapse.
    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // 1. Home Feed
                FeedView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(0)

                // 2. Search & Discovery
                SearchDiscoveryView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)

                // 3. Activity / Notifications
                ActivityView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(2)

                // 4. Profile
                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(3)
            }
            .tint(Color(hex: "#FF00FF")) // Neon Purple Tint

            SpectrumTabBar(selection: $selectedTab)
                .padding(.bottom, 6)
                // Stays put when the search keyboard comes up instead of riding above it.
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onChange(of: selectedTab) { _, newTab in
            TabBarScrollState.shared.activate(tab: newTab)
        }
    }
}

#Preview {
    ContentView()
}
