import SwiftUI

/// Mouse and keyboard tweaks. Lives in the background — no menu bar item.
@MainActor
final class InputModule: MenuBarModule {
    let id = "input"
    let name = "Input"
    let symbol = "computermouse"
    /// Off until asked for: it needs Accessibility.
    let enabledByDefault = false

    private let settings = InputSettings()
    private let permission = AccessibilityPermission()
    private let scroll = ScrollReverser()
    private let remapper = KeyRemapper()
    private let capsTap = CapsTapEscape()
    private var sync: ObservationLoop?

    func activate() {
        guard sync == nil else { return }
        permission.startMonitoring()
        if !permission.isGranted { permission.request() }
        sync = ObservationLoop { [weak self] in
            guard let self else { return }
            // The remap needs no permission, so Caps Lock is Control right away.
            self.remapper.apply(self.settings.keyMappings)
            self.capsTap.timeout = self.settings.tapTimeoutMilliseconds / 1000
            if self.permission.isGranted {
                self.scroll.apply(self.settings.scrollOptions)
                if self.settings.capsLockTapEscape {
                    self.capsTap.start()
                } else {
                    self.capsTap.stop()
                }
            } else {
                self.scroll.stop()
                self.capsTap.stop()
            }
        }
    }

    func deactivate() {
        sync?.cancel()
        sync = nil
        scroll.stop()
        capsTap.stop()
        remapper.clear()
        permission.stopMonitoring()
    }

    func makeSettingsView() -> AnyView {
        AnyView(InputSettingsView(settings: settings, permission: permission, capsTap: capsTap))
    }
}
