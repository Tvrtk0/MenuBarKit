import AppKit
import Observation

enum PlayState: String {
    case playing, paused, stopped
}

struct Track: Equatable {
    var id: String
    var name: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artworkURL: URL?
}

/// What a view needs to draw the current playback, decoupled from the live player
/// so Settings can preview with sample data.
struct NowPlaying {
    var track: Track?
    var state: PlayState
    var position: TimeInterval
    var artwork: NSImage?

    var progress: Double {
        guard let duration = track?.duration, duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    static let sample = NowPlaying(
        track: Track(id: "sample", name: "Stay High - Habits Remix", artist: "Tove Lo",
                     album: "Queen Of The Clouds", duration: 263, artworkURL: nil),
        state: .playing,
        position: 133,
        artwork: nil
    )
}

private let spotifyBundleID = "com.spotify.client"

/// Live Spotify state. Spotify broadcasts track and play/pause changes; between
/// those the position is extrapolated locally and re-synced every few seconds.
@Observable @MainActor
final class SpotifyPlayer {
    private(set) var isRunning = false
    private(set) var isAuthorized = true
    private(set) var state: PlayState = .stopped
    private(set) var track: Track?
    private(set) var artwork: NSImage?
    /// Advances every second while playing; views read it through `position`.
    private(set) var now = Date()

    private var anchorPosition: TimeInterval = 0
    private var anchorDate = Date()

    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var lastSync = Date.distantPast
    @ObservationIgnored private var artworkCache: [String: NSImage] = [:]

    private static let resyncInterval: TimeInterval = 5

    var position: TimeInterval {
        guard let track else { return 0 }
        let elapsed = state == .playing ? now.timeIntervalSince(anchorDate) : 0
        return min(max(anchorPosition + elapsed, 0), track.duration)
    }

    var nowPlaying: NowPlaying {
        NowPlaying(track: track, state: state, position: position, artwork: artwork)
    }

    func start() {
        guard observers.isEmpty else { return }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(
            forName: .init("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }))

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == spotifyBundleID else { return }
                MainActor.assumeIsolated { self?.refresh() }
            }))
        }
        refresh()
    }

    func stop() {
        for (center, observer) in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        ticker?.invalidate()
        ticker = nil
    }

    func refresh() {
        lastSync = Date()
        isRunning = NSRunningApplication.runningApplications(withBundleIdentifier: spotifyBundleID)
            .contains { !$0.isTerminated }
        guard isRunning else {
            apply(nil)
            return
        }
        do {
            let status = try SpotifyScript.fetchStatus()
            isAuthorized = true
            apply(status)
        } catch .notAuthorized {
            isAuthorized = false
            apply(nil)
        } catch {
            apply(nil)
        }
    }

    // MARK: Controls

    func playPause() { command("playpause") }
    func nextTrack() { command("next track") }
    func previousTrack() { command("previous track") }

    func seek(to seconds: TimeInterval) {
        SpotifyScript.send("set player position to \(Int(seconds))")
        anchorPosition = seconds
        anchorDate = Date()
        now = anchorDate
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spotifyBundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func command(_ command: String) {
        SpotifyScript.send(command)
        // Spotify's notification usually lands first; this covers the cases it doesn't.
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            refresh()
        }
    }

    // MARK: State

    private func apply(_ status: SpotifyScript.Status?) {
        let newTrack = status?.track
        let trackChanged = newTrack?.id != track?.id
        if state != status?.state ?? .stopped { state = status?.state ?? .stopped }
        if track != newTrack { track = newTrack }
        anchorPosition = status?.position ?? 0
        anchorDate = Date()
        now = anchorDate
        if trackChanged { loadArtwork() }
        updateTicker()
    }

    private func updateTicker() {
        if state == .playing, ticker == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            // .common keeps the clock running while a menu is open.
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        } else if state != .playing {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func tick() {
        if Date().timeIntervalSince(lastSync) >= Self.resyncInterval {
            refresh()
        } else {
            now = Date()
        }
    }

    private func loadArtwork() {
        guard let track, let url = track.artworkURL else {
            artwork = nil
            return
        }
        if let cached = artworkCache[track.id] {
            artwork = cached
            return
        }
        artwork = nil
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data),
                  self.track?.id == track.id
            else { return }
            if artworkCache.count > 50 { artworkCache.removeAll() }
            artworkCache[track.id] = image
            artwork = image
        }
    }
}
