import SwiftUI

struct InputSettingsView: View {
    @Bindable var settings: InputSettings
    let permission: AccessibilityPermission

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    if permission.isGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings") { permission.openSystemSettings() }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("Needed to change scroll events. Only scroll events are watched — never key presses.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Reverse mouse wheel — vertical", isOn: $settings.reverseMouseVertical)
                Toggle("Reverse mouse wheel — horizontal", isOn: $settings.reverseMouseHorizontal)
                Toggle("Reverse trackpad and Magic Mouse", isOn: $settings.reverseTrackpad)
            } header: {
                Text("Scrolling")
            } footer: {
                Text("Relative to the system “Natural scrolling” setting, which applies to every device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
