import AppKit
import SwiftUI

/// App-wide state shared by the core and every module.
@Observable @MainActor
final class AppServices {
    static let shared = AppServices()

    let updater = Updater()
    let modules: ModuleManager

    /// A small MenuBarKit icon that only opens the menu — a handle on the app when
    /// all module items are hidden.
    var showCoreIcon: Bool {
        didSet {
            UserDefaults.standard.set(showCoreIcon, forKey: "showCoreIcon")
            syncCoreIcon()
        }
    }

    @ObservationIgnored private var coreItem: StatusItemController?
    @ObservationIgnored private var settingsWindow: NSWindow?

    private init() {
        modules = ModuleManager(modules: [SpotifyModule()])
        showCoreIcon = UserDefaults.standard.bool(forKey: "showCoreIcon")
    }

    func start() {
        modules.activateEnabled()
        syncCoreIcon()
        updater.start()
    }

    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsRootView(services: self)))
            window.title = "MenuBarKit"
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 720, height: 540))
            window.center()
            window.setFrameAutosaveName("Settings")
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func syncCoreIcon() {
        if showCoreIcon, coreItem == nil {
            coreItem = StatusItemController(
                autosaveName: "MenuBarKit.core",
                label: Image(systemName: "menubar.rectangle")
            )
        } else if !showCoreIcon, let item = coreItem {
            item.remove()
            coreItem = nil
        }
    }
}
