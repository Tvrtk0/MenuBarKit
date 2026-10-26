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
                VStack(spacing: 0) {
                    HStack {
                        Label(module.name, systemImage: module.symbol).font(.title3.bold())
                        Spacer()
                        Toggle("Enabled", isOn: Binding(
                            get: { services.modules.isEnabled(module) },
                            set: { services.modules.setEnabled(module, $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    Divider()
                    module.makeSettingsView()
                }
                .navigationTitle(module.name)
            } else {
                GeneralSettingsView(services: services)
                    .navigationTitle("General")
            }
        }
        .frame(minWidth: 640, minHeight: 460)
    }
}
