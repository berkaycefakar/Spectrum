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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Supabase Auth deep links (email confirmation, magic links, etc.)
                    SupabaseManager.shared.client.handle(url)
                }
                .task {
                    // Request MusicKit authorization on launch (best practice).
                    // Catalog search works without authorization, but this ensures
                    // full MusicKit features are available when needed.
                    await MusicService.shared.requestMusicAuthorization()
                }
        }
    }
}
