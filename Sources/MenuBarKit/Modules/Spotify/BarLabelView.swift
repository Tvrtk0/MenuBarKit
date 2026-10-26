import AppKit
import SwiftUI

/// The Spotify item's menu bar label, built from the enabled elements in order.
/// Adjacent artist and title merge into one "Artist – Title" run.
struct BarLabelView: View {
    let nowPlaying: NowPlaying
    let settings: SpotifySettings

    private enum Segment {
        case artwork, playState, text(String), time, progressBar
    }

    var body: some View {
        let segments = nowPlaying.track.map(segments(for:)) ?? []
        Group {
            if segments.isEmpty {
                Image(systemName: "music.note")
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        view(for: segment)
                    }
                }
                .opacity(nowPlaying.state == .paused && settings.dimWhenPaused ? 0.5 : 1)
            }
        }
        .font(.menuBar)
    }

    private func segments(for track: Track) -> [Segment] {
        var result: [Segment] = []
        var pendingText: [String] = []
        func flushText() {
            if !pendingText.isEmpty {
                result.append(.text(pendingText.joined(separator: " – ")))
                pendingText.removeAll()
            }
        }
        for config in settings.elements where config.isEnabled {
            switch config.element {
            case .artist where !track.artist.isEmpty: pendingText.append(track.artist)
            case .title where !track.name.isEmpty: pendingText.append(track.name)
            case .artist, .title: break
            case .artwork: flushText(); result.append(.artwork)
            case .playState: flushText(); result.append(.playState)
            case .time: flushText(); result.append(.time)
            case .progressBar: flushText(); result.append(.progressBar)
            }
        }
        flushText()
        return result
    }

    @ViewBuilder private func view(for segment: Segment) -> some View {
        switch segment {
        case .artwork:
            artwork
        case .playState:
            Image(systemName: nowPlaying.state == .playing ? "play.fill" : "pause.fill")
                .font(.system(size: 10))
        case .text(let text):
            MenuBarText(text: text, maxWidth: settings.maxTextWidth)
        case .time:
            Text("\(formatTime(nowPlaying.position))/\(formatTime(nowPlaying.track?.duration ?? 0))")
                .monospacedDigit()
        case .progressBar:
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.25))
                Capsule().fill(.primary)
                    .frame(width: settings.progressBarWidth * nowPlaying.progress)
            }
            .frame(width: settings.progressBarWidth, height: 3)
        }
    }

    private var artwork: some View {
        ZStack {
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 3).fill(.primary.opacity(0.15))
                Image(systemName: "music.note").font(.system(size: 9))
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let (hours, minutes, secs) = (total / 3600, total / 60 % 60, total % 60)
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}
