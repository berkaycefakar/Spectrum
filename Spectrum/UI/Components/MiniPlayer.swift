import SwiftUI

/// The persistent preview bar.
///
/// Previews used to be controlled only by the card that started them: scroll it off screen or
/// push a detail view on top and the sound kept playing with no way to stop it short of
/// finding that exact card again. This sits above the tab bar for as long as something is
/// playing and gives it somewhere to be.
struct MiniPlayer: View {
    @ObservedObject private var audioManager = AudioManager.shared

    /// Called when the bar itself is tapped, so the host can open the track's page.
    var onTap: (Track) -> Void = { _ in }

    var body: some View {
        if let track = audioManager.currentTrack {
            HStack(spacing: 12) {
                AsyncImage(url: track.artworkUrl600) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.white.opacity(0.08)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    audioManager.toggle(track: track)
                } label: {
                    Group {
                        if audioManager.isBuffering {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    // A fixed box so the icon doesn't shift when the spinner swaps in.
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(audioManager.isPlaying ? "Pause preview" : "Resume preview")

                Button {
                    audioManager.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop preview")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Two single lines beside a fixed 38pt thumbnail: bounded for the same reason
            // the tab bar is. The track's own page shows the full title at any size.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
            // The whole bar opens the track, but the two buttons above claim their own taps
            // first — `contentShape` on a `Capsule` keeps the gap between them inert.
            .contentShape(Capsule())
            .onTapGesture { onTap(track) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
        }
    }
}
