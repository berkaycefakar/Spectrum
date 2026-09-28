import AVFoundation
import Combine

/// Centralized audio manager — ensures only one track plays at a time
/// and properly cleans up observers to prevent memory leaks.
@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var currentTrackId: Int?
    /// The track behind `currentTrackId`.
    ///
    /// The id alone was enough while the only controls were on the card that started the
    /// sound. A mini-player outlives that card — you scroll it away, or push a whole screen
    /// on top — so the player has to carry enough to draw itself.
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    /// True while the preview is fetched/buffered but no sound is coming out yet.
    ///
    /// Without this the UI flipped straight to a pause icon on tap and then sat silent for
    /// several seconds — the button looked broken when it was really just downloading.
    @Published var isBuffering = false
    /// How far into the preview we are, in seconds.
    ///
    /// Published so a player UI can draw a progress bar. Updated four times a second — often
    /// enough to look continuous, rare enough that it isn't a per-frame main-actor wake-up.
    @Published var currentTime: Double = 0
    /// The preview's length. 30 seconds for an Apple preview, but read from the asset rather
    /// than assumed — nothing in the catalog promises that number.
    @Published var duration: Double = 0
    /// True while a drag on the progress bar is in flight, so the periodic observer doesn't
    /// yank the knob back to where playback still is.
    private var isSeeking = false

    private var player: AVPlayer?
    private var endObserver: AnyCancellable?
    private var statusObserver: AnyCancellable?
    /// Must be handed back to the *same* player it came from, so it is cleared in lockstep
    /// with `player` — removing it from a different one traps.
    private var timeObserver: Any?

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
                debugLog("Audio session error: \(error)")
            }
        }
    }

    /// Hands the session back so whatever was playing before can resume.
    private func deactivateSession() {
        sessionQueue.async {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                debugLog("Audio session deactivation error: \(error)")
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

    /// True when this track is the one loaded in the player, playing or paused.
    func isTrackLoaded(_ trackId: Int) -> Bool {
        currentTrackId == trackId
    }

    /// 0...1 through the preview. Zero until the duration is known, so a progress bar
    /// doesn't jump about while the asset is still loading.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    /// Seconds remaining, for the countdown label.
    var remainingTime: Double {
        max(duration - currentTime, 0)
    }

    /// Moves playback to `fraction` (0...1) of the preview.
    ///
    /// The UI drives this from a drag, which fires continuously — so the knob's position is
    /// held locally for the duration of the seek and the periodic observer is ignored until
    /// it lands. Without that the bar visibly fought the drag.
    func seek(toFraction fraction: Double) {
        guard let player, duration > 0 else { return }
        let seconds = min(max(fraction, 0), 1) * duration
        isSeeking = true
        currentTime = seconds
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in self?.isSeeking = false }
        }
    }

    /// Resumes, or restarts a preview that has already played out.
    ///
    /// The end-of-item handler drops `currentTrack`, so after a preview finishes there is no
    /// player left to resume — `toggle` handles that by loading it again.
    func restart() {
        guard let player else { return }
        seek(toFraction: 0)
        activateSession()
        player.play()
        isPlaying = true
    }

    /// Toggle play/pause for a track. Stops any other playing track.
    func toggle(track: Track) {
        toggle(trackId: track.id, previewUrl: track.previewUrl, track: track)
    }

    /// Toggle play/pause for a track. Stops any other playing track.
    func toggle(trackId: Int, previewUrl: String?, track: Track? = nil) {
        // Same track — toggle
        if currentTrackId == trackId {
            if isPlaying {
                player?.pause()
                isPlaying = false
                deactivateSession()
            } else {
                // A preview parked at its end has nowhere left to play, so resuming has to
                // rewind first — otherwise the button flipped to "pause" and sat silent.
                if duration > 0, currentTime >= duration - 0.1 {
                    restart()
                } else {
                    activateSession()
                    player?.play()
                    isPlaying = true
                }
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
        currentTrack = track
        isPlaying = true
        isBuffering = true
        currentTime = 0
        duration = 0
        newPlayer.play()

        // Four ticks a second drives the progress bar. The duration is read here too rather
        // than awaited up front: `AVPlayerItem` reports `.indefinite` until the asset's
        // header has been parsed, and a preview that starts sooner matters more than knowing
        // its length a moment earlier.
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let itemDuration = newPlayer.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                guard !self.isSeeking else { return }
                self.currentTime = time.seconds
            }
        }

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
                guard let self else { return }
                self.isPlaying = false
                self.isBuffering = false
                // The track stays loaded, parked at the end. Clearing it here used to make the
                // mini-player vanish the instant a preview ran out, taking the one control
                // that could play it again with it.
                self.currentTime = self.duration
                self.deactivateSession()
            }
    }

    func stop() {
        let wasActive = player != nil
        player?.pause()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player = nil
        endObserver = nil
        statusObserver = nil
        currentTrackId = nil
        currentTrack = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        if wasActive { deactivateSession() }
    }
}
