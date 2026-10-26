import Foundation
import Observation

@Observable @MainActor
final class ModuleManager {
    let modules: [any MenuBarModule]
    private(set) var enabledIDs: Set<String>

    init(modules: [any MenuBarModule]) {
        self.modules = modules
        let defaults = UserDefaults.standard
        enabledIDs = Set(modules.map(\.id).filter { id in
            defaults.object(forKey: Self.key(id)) as? Bool ?? true
        })
    }

    func activateEnabled() {
        for module in modules where enabledIDs.contains(module.id) {
            module.activate()
        }
    }

    func isEnabled(_ module: any MenuBarModule) -> Bool {
        enabledIDs.contains(module.id)
    }

    func setEnabled(_ module: any MenuBarModule, _ enabled: Bool) {
        guard enabled != isEnabled(module) else { return }
        UserDefaults.standard.set(enabled, forKey: Self.key(module.id))
        if enabled {
            enabledIDs.insert(module.id)
            module.activate()
        } else {
            enabledIDs.remove(module.id)
            module.deactivate()
        }
    }

    func module(withID id: String) -> (any MenuBarModule)? {
        modules.first { $0.id == id }
    }

    private static func key(_ id: String) -> String { "module.\(id).enabled" }
}
