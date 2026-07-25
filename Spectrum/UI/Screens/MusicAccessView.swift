import SwiftUI
import UIKit

/// Shown when Apple Music access was declined or is restricted. Explains what breaks, what it
/// costs (nothing — no subscription needed), and gets the user to the one switch that fixes it.
struct MusicAccessView: View {
    let onContinueAnyway: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Color(hex: "#5856D6")
                .opacity(0.25)
                .blur(radius: 120)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                SpectrumMark(size: 72)

                VStack(spacing: 12) {
                    Text("Spectrum needs Apple Music")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Every song, album and artist in Spectrum comes from the Apple Music catalogue. Without access there's nothing to search, log or rate.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 14) {
                    reassurance(
                        icon: "checkmark.seal.fill",
                        text: "No subscription required — search, artwork and 30-second previews are free."
                    )
                    reassurance(
                        icon: "music.note.list",
                        text: "Spectrum never plays full songs and never touches your library."
                    )
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        openSettings()
                    } label: {
                        Text("Open Settings")
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#FF00FF"), Color(hex: "#5856D6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }

                    Text("Settings → Spectrum → Media & Apple Music")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))

                    Button("Look around anyway", action: onContinueAnyway)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func reassurance(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#FF00FF"))
                .frame(width: 20)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Deep-links straight to Spectrum's own page in Settings, where the Media & Apple Music
    /// toggle lives. Buried four levels down otherwise.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MusicAccessView(onContinueAnyway: {})
}
