import SwiftUI

struct NowPlayingPopover: View {
    let player: SpotifyPlayer
    let updater: Updater

    /// Slider value while dragging; nil follows playback.
    @State private var scrubPosition: TimeInterval?

    var body: some View {
        VStack(spacing: 14) {
            if !player.isAuthorized {
                permissionNotice
            } else if let track = player.track {
                nowPlaying(track)
            } else {
                emptyState
            }

            if updater.isUpdateAvailable {
                Button {
                    updater.installUpdate()
                } label: {
                    Label("Update available — install & restart", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()
            HStack {
                Button("Open Spotify") { player.openSpotify() }
                Spacer()
                Button {
                    AppServices.shared.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
    }

    private func nowPlaying(_ track: Track) -> some View {
        VStack(spacing: 12) {
            Group {
                if let image = player.artwork {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "music.note").font(.system(size: 48)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 268, height: 268)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 2) {
                Text(track.name).font(.headline)
                Text(track.artist).foregroundStyle(.secondary)
                if !track.album.isEmpty {
                    Text(track.album).font(.caption).foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .multilineTextAlignment(.center)

            VStack(spacing: 2) {
                Slider(
                    value: Binding(get: { scrubPosition ?? player.position }, set: { scrubPosition = $0 }),
                    in: 0...max(track.duration, 1)
                ) { editing in
                    if !editing, let target = scrubPosition {
                        player.seek(to: target)
                        scrubPosition = nil
                    }
                }
                .controlSize(.small)
                HStack {
                    Text(formatTime(scrubPosition ?? player.position))
                    Spacer()
                    Text(formatTime(track.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 36) {
                Button { player.previousTrack() } label: { Image(systemName: "backward.fill") }
                Button { player.playPause() } label: {
                    Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .frame(width: 36)
                }
                Button { player.nextTrack() } label: { Image(systemName: "forward.fill") }
            }
            .font(.system(size: 20))
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note").font(.system(size: 32)).foregroundStyle(.secondary)
            Text(player.isRunning ? "Nothing playing" : "Spotify isn't running")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MenuBarKit can't talk to Spotify", systemImage: "lock")
                .font(.headline)
            Text("Allow it in System Settings → Privacy & Security → Automation → MenuBarKit → Spotify.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open Automation settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            }
        }
    }
}
