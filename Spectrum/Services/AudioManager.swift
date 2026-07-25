import AVFoundation
import Combine

/// Centralized audio manager — ensures only one track plays at a time
/// and properly cleans up observers to prevent memory leaks.
@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var currentTrackId: Int?
    @Published var isPlaying = false
    /// True while the preview is fetched/buffered but no sound is coming out yet.
    ///
    /// Without this the UI flipped straight to a pause icon on tap and then sat silent for
    /// several seconds — the button looked broken when it was really just downloading.
    @Published var isBuffering = false

    private var player: AVPlayer?
    private var endObserver: AnyCancellable?
    private var statusObserver: AnyCancellable?

    /// Audio-session calls are synchronous IPC to mediaserverd and the *first* one in a
    /// process regularly costs hundreds of milliseconds. On the main actor that is frozen UI,
    /// so all of it happens here instead. Serial, so activate/deactivate can't interleave.
    private let sessionQueue = DispatchQueue(label: "com.spectrum.audio-session")

    private init() {}

    /// Claims the audio session, and only when a preview is actually about to play.
    ///
    /// This used to run at init — i.e. the first time anything touched `AudioManager.shared`,
    /// which is during app launch. Activating a `.playback` session silences whatever the
    /// user was already listening to, so simply opening Spectrum stopped their music even if
    /// they never pressed play on anything.
    private func activateSession() {
        sessionQueue.async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                print("Audio session error: \(error)")
            }
        }
    }

    /// Hands the session back so whatever was playing before can resume.
    private func deactivateSession() {
        sessionQueue.async {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Audio session deactivation error: \(error)")
            }
        }
    }

    /// Check if a specific track is currently playing
    func isTrackPlaying(_ trackId: Int) -> Bool {
        currentTrackId == trackId && isPlaying
    }

    /// True when *this* track is the one still loading.
    func isTrackBuffering(_ trackId: Int) -> Bool {
        currentTrackId == trackId && isBuffering
    }

    /// Toggle play/pause for a track. Stops any other playing track.
    func toggle(trackId: Int, previewUrl: String?) {
        // Same track — toggle
        if currentTrackId == trackId {
            if isPlaying {
                player?.pause()
                isPlaying = false
                deactivateSession()
            } else {
                activateSession()
                player?.play()
                isPlaying = true
            }
            return
        }

        // Different track — stop current, play new
        stop()

        guard let urlString = previewUrl, let url = URL(string: urlString) else { return }

        activateSession()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)

        // These are 30-second previews. The default policy buffers extra up front to avoid
        // future stalls, which is the wrong trade here — a preview that starts a second
        // sooner beats one that never stutters.
        newPlayer.automaticallyWaitsToMinimizeStalling = false

        player = newPlayer
        currentTrackId = trackId
        isPlaying = true
        isBuffering = true
        newPlayer.play()

        // `timeControlStatus` is the only honest source for "is sound actually coming out".
        statusObserver = newPlayer
            .publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isBuffering = (status == .waitingToPlayAtSpecifiedRate)
            }

        // Observe end using Combine — no retain cycle, auto-cleanup
        endObserver = NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.isBuffering = false
                self?.currentTrackId = nil
                self?.deactivateSession()
            }
    }

    func stop() {
        let wasActive = player != nil
        player?.pause()
        player = nil
        endObserver = nil
        statusObserver = nil
        currentTrackId = nil
        isPlaying = false
        isBuffering = false
        if wasActive { deactivateSession() }
    }
}
