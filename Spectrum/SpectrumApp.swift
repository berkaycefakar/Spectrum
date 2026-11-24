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
        launchTrace("app init")
        // AsyncImage goes through URLSession.shared, and the default cache is far too small
        // for a grid of album art — artwork was being refetched on every re-render, which is
        // what made search feel sluggish while typing.
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
    }

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var musicAuth = MusicAuthorizationStore.shared
    @StateObject private var language = LanguagePreference.shared

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "spectrum.wordmarkGallery") {
                WordmarkGallery()
            } else {
                root
            }
            #else
            root
            #endif
        }
    }

    private var root: some View {
            ContentView()
                // `.id` forces the whole tree to rebuild when the language changes. The
                // bundle swap makes new lookups return the other language, but views already
                // on screen keep the string they resolved at build time — without this, the
                // switch only took effect on screens you navigated to afterwards.
                .id(language.choice)
                // Dates and numbers resolve through `Locale`, not the bundle, so they are
                // told separately. On `.system` this is `.autoupdatingCurrent`, i.e. no change.
                .environment(\.locale, language.locale)
                .onOpenURL { url in
                    // Only Supabase's own callback is an auth link. Any app or web page can
                    // open spectrum://, so a URL saying "type=recovery" proves nothing by
                    // itself: recovery mode starts only after the link has actually been
                    // exchanged for a session (a forged code fails the PKCE exchange, which
                    // needs the verifier stored on this device). Before this, any
                    // spectrum://x?type=recovery link put a signed-in user on a password
                    // screen they could only leave by changing the password or signing out.
                    guard url.host == "auth-callback" else { return }
                    // Checked before the exchange: PKCE reports a recovery link as a plain
                    // `.signedIn`, so the URL is the only place it says what it was for.
                    let isRecovery = AuthDeepLink.isPasswordRecovery(url)
                    Task {
                        do {
                            _ = try await SupabaseManager.shared.client.auth.session(from: url)
                            if isRecovery { SessionStore.shared.beginPasswordRecovery() }
                        } catch {
                            debugLog("Auth callback rejected: \(error)")
                        }
                    }
                }
                .task {
                    // Catalog search requires this — without `.authorized` every MusicKit
                    // request throws and the app shows empty feeds and empty search results.
                    // The demo runs without an Apple Music account; asking would cover the screen.
                    if !DemoMode.isOn { await musicAuth.requestIfNeeded() }
                    await PushManager.shared.registerIfSignedIn()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // iOS doesn't notify us when the user flips the Media & Apple Music switch
                    // in Settings, so re-read it whenever we come back to the foreground.
                    if newPhase == .active {
                        musicAuth.refresh()
                        // With no push notifications, coming back to the app is the only
                        // moment we get to find out that something happened while it was
                        // closed. Three `limit 1` reads — cheap enough to do every time.
                        Task { await ActivityBadgeStore.shared.refresh() }
                        Task { await PushManager.shared.registerIfSignedIn() }
                    }
                }
        }
}
