import SwiftUI

struct SettingsRootView: View {
    let services: AppServices
    @State private var selection: String? = "general"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape").tag("general")
                Section("Modules") {
                    ForEach(services.modules.modules, id: \.id) { module in
                        Label(module.name, systemImage: module.symbol).tag(module.id)
                    }
                }
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            if let id = selection, let module = services.modules.module(withID: id) {
                module.makeSettingsView()
                    .navigationTitle(module.name)
            } else {
                GeneralSettingsView(services: services)
                    .navigationTitle("General")
            }
        }
        .frame(minWidth: 640, minHeight: 460)
    }
}
