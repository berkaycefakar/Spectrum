import AVFoundation
import Combine

/// Centralized audio manager — ensures only one track plays at a time
/// and properly cleans up observers to prevent memory leaks.
@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var currentTrackId: Int?
    @Published var isPlaying = false

    private var player: AVPlayer?
    private var endObserver: AnyCancellable?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    /// Check if a specific track is currently playing
    func isTrackPlaying(_ trackId: Int) -> Bool {
        currentTrackId == trackId && isPlaying
    }

    /// Toggle play/pause for a track. Stops any other playing track.
    func toggle(trackId: Int, previewUrl: String?) {
        // Same track — toggle
        if currentTrackId == trackId {
            if isPlaying {
                player?.pause()
                isPlaying = false
            } else {
                player?.play()
                isPlaying = true
            }
            return
        }

        // Different track — stop current, play new
        stop()

        guard let urlString = previewUrl, let url = URL(string: urlString) else { return }

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        currentTrackId = trackId
        isPlaying = true

        // Observe end using Combine — no retain cycle, auto-cleanup
        endObserver = NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.currentTrackId = nil
            }
    }

    func stop() {
        player?.pause()
        player = nil
        endObserver = nil
        currentTrackId = nil
        isPlaying = false
    }
}
