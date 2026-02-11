//
//  SpectrumApp.swift
//  Spectrum
//
//  Created by Berkay on 25.01.2026.
//

import SwiftUI
import SwiftData
import Supabase

@main
struct SpectrumApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle Supabase Auth deep links (email confirmation, magic links, etc.)
                    SupabaseManager.shared.client.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
