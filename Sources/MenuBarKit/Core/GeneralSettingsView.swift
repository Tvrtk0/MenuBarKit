import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var services: AppServices
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show MenuBarKit icon in the menu bar", isOn: $services.showCoreIcon)
            } footer: {
                Text("Opening MenuBarKit again from Spotlight or Finder always brings up this window.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Modules") {
                ForEach(services.modules.modules, id: \.id) { module in
                    Toggle(isOn: Binding(
                        get: { services.modules.isEnabled(module) },
                        set: { services.modules.setEnabled(module, $0) }
                    )) {
                        Label(module.name, systemImage: module.symbol)
                    }
                }
            }

            UpdatesSection(updater: services.updater)
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct UpdatesSection: View {
    let updater: Updater

    var body: some View {
        Section("Updates") {
            LabeledContent("Version") {
                Text("\(updater.version) (\(String((updater.commit ?? "dev").prefix(7))))")
                    .textSelection(.enabled)
            }
            LabeledContent("Status") {
                statusText
            }
            if let lastChecked = updater.lastChecked {
                LabeledContent("Last checked") {
                    Text(lastChecked, format: .relative(presentation: .named))
                }
            }
            HStack {
                Button("Check now") { Task { await updater.check() } }
                    .disabled(updater.status == .checking || updater.status == .updating)
                if updater.isUpdateAvailable {
                    Button("Update & restart") { updater.installUpdate() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Show log") { updater.revealLog() }
            }
            if let sourceDir = updater.sourceDir {
                Text("Built from \(sourceDir)")
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private var statusText: some View {
        switch updater.status {
        case .idle: Text("Not checked yet").foregroundStyle(.secondary)
        case .checking: Text("Checking…")
        case .upToDate: Text("Up to date")
        case .available(let commits): Text("Update available (\(commits) new commit\(commits == 1 ? "" : "s"))")
        case .updating: Text("Updating — the app will restart…")
        case .failed(let message): Text(message).foregroundStyle(.red)
        }
    }
}
