import SwiftUI

/// A self-contained feature that lives in the menu bar. Modules own their status
/// items and settings; the core only switches them on and off and hosts their
/// settings page.
@MainActor
protocol MenuBarModule: AnyObject {
    /// Stable key, used for persisted settings — never rename.
    var id: String { get }
    var name: String { get }
    /// SF Symbol shown next to the module in the Settings sidebar.
    var symbol: String { get }

    func activate()
    func deactivate()
    func makeSettingsView() -> AnyView
}
