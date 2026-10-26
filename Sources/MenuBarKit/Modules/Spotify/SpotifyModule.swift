import SwiftUI

@MainActor
final class SpotifyModule: MenuBarModule {
    let id = "spotify"
    let name = "Spotify"
    let symbol = "music.note"

    private let player = SpotifyPlayer()
    private let settings = SpotifySettings()
    private var statusItem: StatusItemController?
    private var visibility: ObservationLoop?

    func activate() {
        guard statusItem == nil else { return }
        player.start()
        let item = StatusItemController(
            autosaveName: "MenuBarKit.spotify",
            label: SpotifyBarLabel(player: player, settings: settings),
            popover: AnyView(NowPlayingPopover(player: player, updater: AppServices.shared.updater))
        )
        item.onPopoverWillShow = { [player] in player.refresh() }
        statusItem = item
        visibility = ObservationLoop { [weak self] in
            guard let self else { return }
            self.statusItem?.isVisible = self.player.track != nil || self.settings.idleBehavior == .icon
        }
    }

    func deactivate() {
        visibility?.cancel()
        visibility = nil
        statusItem?.remove()
        statusItem = nil
        player.stop()
    }

    func makeSettingsView() -> AnyView {
        AnyView(SpotifySettingsView(player: player, settings: settings))
    }
}

/// Reads the player inside `body` so SwiftUI re-renders on every observed change.
private struct SpotifyBarLabel: View {
    let player: SpotifyPlayer
    let settings: SpotifySettings

    var body: some View {
        BarLabelView(nowPlaying: player.nowPlaying, settings: settings)
    }
}
