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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Supabase Auth deep links (email confirmation, magic links, etc.)
                    SupabaseManager.shared.client.handle(url)
                }
                .task {
                    // Catalog search requires this — without `.authorized` every MusicKit
                    // request throws and the app shows empty feeds and empty search results.
                    await MusicService.shared.requestMusicAuthorization()
                }
        }
    }
}
