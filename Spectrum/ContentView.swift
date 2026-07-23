import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var sessionStore = SessionStore.shared
    @State private var selectedTab = 0
    @State private var showAuthView = false
    
    init() {
        // Customize Tab Bar Appearance for Glassmorphism
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
        .task {
            await sessionStore.checkSession()
        }
    }
    
    // MARK: - Main Tab View
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // 1. Home Feed
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            // 2. Search & Discovery
            SearchDiscoveryView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            // 3. Activity / Notifications
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .tag(2)
            
            // 4. Profile
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(Color(hex: "#FF00FF")) // Neon Purple Tint
    }
}

#Preview {
    ContentView()
}
