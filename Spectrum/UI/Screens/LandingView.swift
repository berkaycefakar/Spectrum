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
    
    // Demo track for preview card
    let demoTrack = Track(
        id: 1488408568,
        title: "Blinding Lights",
        artist: "The Weeknd",
        artworkUrl100: "https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/a0/4d/a4/a04da453-3a4b-851b-5813-2b20aa8024e0/source/100x100bb.jpg",
        previewUrl: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/7b/2f/1e/7b2f1e62-62d2-1a64-5666-326e63785547/mzaf_2864609346649723364.plus.aac.p.m4a"
    )
    
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
            
            // Terms text
            Text("By continuing, you agree to our Terms of Service")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
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
