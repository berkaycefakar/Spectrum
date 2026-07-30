import SwiftUI

/// Welcome / Landing Screen
/// The first, highly visual entry screen with liquid gradient background
struct LandingView: View {
    /// Callback when user taps "Get Started"
    var onGetStarted: () -> Void
    
    // Animation states for liquid effect
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    @State private var animateBlob3 = false
    @State private var showContent = false
    
    // Demo track for preview card.
    //
    // Both URLs used to be hardcoded from 2020 and both now return 404 — Apple re-issues these
    // paths when a record is re-released or re-mastered. The visible result was a grey box
    // where the album art should be, and a play button that did nothing, as the first thing a
    // new user ever saw. These are current, and `refreshDemoTrack()` re-resolves them at
    // runtime so the screen heals itself the next time Apple moves the files.
    private static let demoTrackId = 1488408568
    @State private var demoArtworkUrl = "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a6/6e/bf/a66ebf79-5008-8948-b352-a790fc87446b/19UM1IM04638.rgb.jpg/100x100bb.jpg"
    @State private var demoPreviewUrl: String? = "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/17/b4/8f/17b48f9a-0b93-6bb8-fe1d-3a16623c2cfb/mzaf_9560252727299052414.plus.aac.p.m4a"

    private var demoTrack: Track {
        Track(
            id: Self.demoTrackId,
            title: "Blinding Lights",
            artist: "The Weeknd",
            artworkUrl100: demoArtworkUrl,
            previewUrl: demoPreviewUrl
        )
    }

    var body: some View {
        ZStack {
            // Deep swirling liquid gradient background
            liquidBackground
            
            VStack(spacing: 0) {
                Spacer()
                
                // Glowing Logo
                logoSection
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Spacer()
                
                // Demo Card with 3D effect
                TrackCardView(
                    track: demoTrack,
                    vibeColor: Color(hex: "#FF0055")
                )
                .scaleEffect(0.85)
                .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0))
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                
                Spacer()
                
                // Frosted Glass Panel with CTA
                ctaPanel
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 50)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animateBlob1 = true
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true).delay(0.5)) {
                animateBlob2 = true
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(1)) {
                animateBlob3 = true
            }
            // Fade in content
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showContent = true
            }
        }
        .task {
            await refreshDemoTrack()
        }
    }

    /// Re-resolves the demo card's artwork and preview from Apple.
    ///
    /// Deliberately the public iTunes lookup endpoint rather than MusicKit: this screen is
    /// shown *before* login and before the Apple Music permission prompt, so a MusicKit
    /// request here would simply fail. Nothing breaks if this call doesn't come back — the
    /// bundled URLs above are valid, so the card already looks right.
    private func refreshDemoTrack() async {
        struct LookupResponse: Decodable {
            struct Item: Decodable {
                let artworkUrl100: String?
                let previewUrl: String?
            }
            let results: [Item]
        }

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(Self.demoTrackId)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let item = decoded.results.first else { return }

            await MainActor.run {
                if let artwork = item.artworkUrl100, artwork != demoArtworkUrl {
                    demoArtworkUrl = artwork
                }
                if let preview = item.previewUrl, preview != demoPreviewUrl {
                    demoPreviewUrl = preview
                }
            }
        } catch {
            print("Landing: couldn't refresh the demo track artwork:", error)
        }
    }
    
    // MARK: - Liquid Background
    private var liquidBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(hex: "#0a0a0f"),
                    Color(hex: "#0f0c29"),
                    Color(hex: "#1a1a2e")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated purple blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#FF00FF").opacity(0.6), Color(hex: "#FF00FF").opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(
                    x: animateBlob1 ? -80 : -120,
                    y: animateBlob1 ? -250 : -180
                )
            
            // Animated cyan blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#00FFFF").opacity(0.5), Color(hex: "#00FFFF").opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .blur(radius: 50)
                .offset(
                    x: animateBlob2 ? 100 : 60,
                    y: animateBlob2 ? 250 : 180
                )
            
            // Smaller accent blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#5856D6").opacity(0.4), Color(hex: "#5856D6").opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 250, height: 250)
                .blur(radius: 40)
                .offset(
                    x: animateBlob3 ? -50 : 50,
                    y: animateBlob3 ? 100 : 50
                )
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 12) {
            // Logo text with neon glow
            Text("Spectrum")
                .font(.system(size: 52, weight: .heavy, design: .default))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.8), radius: 2)
                .shadow(color: Color(hex: "#FF00FF").opacity(0.5), radius: 20)
                .shadow(color: Color(hex: "#00FFFF").opacity(0.3), radius: 40)
            
            Text("Feel the Music in Color")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.6))
                .tracking(3)
                .textCase(.uppercase)
        }
        .padding(.top, 60)
    }
    
    // MARK: - CTA Panel
    private var ctaPanel: some View {
        VStack(spacing: 16) {
            // Get Started Button (Primary)
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            // Terms text. These have to be real links, not a sentence: Guideline 1.2 expects
            // an EULA the user can actually read and agree to before posting content.
            VStack(spacing: 2) {
                Text("By continuing, you agree to our")
                HStack(spacing: 4) {
                    Link("Terms of Service", destination: LegalLinks.terms)
                        .underline()
                    Text("and")
                    Link("Privacy Policy", destination: LegalLinks.privacy)
                        .underline()
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
            .tint(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

#Preview {
    LandingView(onGetStarted: {})
}
