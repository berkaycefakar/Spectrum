//
//  SpectrumApp.swift
//  Spectrum
//
//  Created by Berkay on 25.01.2026.
//

import SwiftUI
import Supabase
import MusicKit

@main
struct SpectrumApp: App {
    init() {
        // AsyncImage goes through URLSession.shared, and the default cache is far too small
        // for a grid of album art — artwork was being refetched on every re-render, which is
        // what made search feel sluggish while typing.
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var musicAuth = MusicAuthorizationStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Check what the link is for *before* handing it over: the PKCE flow
                    // exchanges the callback and reports a plain `.signedIn`, so a recovery
                    // link would otherwise just log the user in and leave the password they
                    // forgot in place.
                    if AuthDeepLink.isPasswordRecovery(url) {
                        SessionStore.shared.beginPasswordRecovery()
                    }
                    // Handle Supabase Auth deep links (email confirmation, magic links, etc.)
                    SupabaseManager.shared.client.handle(url)
                }
                .task {
                    // Catalog search requires this — without `.authorized` every MusicKit
                    // request throws and the app shows empty feeds and empty search results.
                    await musicAuth.requestIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // iOS doesn't notify us when the user flips the Media & Apple Music switch
                    // in Settings, so re-read it whenever we come back to the foreground.
                    if newPhase == .active { musicAuth.refresh() }
                }
        }
    }
}
