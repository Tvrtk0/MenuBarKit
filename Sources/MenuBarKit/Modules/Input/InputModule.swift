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
    private var sync: ObservationLoop?

    func activate() {
        guard sync == nil else { return }
        permission.startMonitoring()
        if !permission.isGranted { permission.request() }
        sync = ObservationLoop { [weak self] in
            guard let self else { return }
            if self.permission.isGranted {
                self.scroll.apply(self.settings.scrollOptions)
            } else {
                self.scroll.stop()
            }
        }
    }

    func deactivate() {
        sync?.cancel()
        sync = nil
        scroll.stop()
        permission.stopMonitoring()
    }

    func makeSettingsView() -> AnyView {
        AnyView(InputSettingsView(settings: settings, permission: permission))
    }
}
