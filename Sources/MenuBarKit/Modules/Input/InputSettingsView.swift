import SwiftUI

struct InputSettingsView: View {
    @Bindable var settings: InputSettings
    let permission: AccessibilityPermission
    let capsTap: CapsTapEscape

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
                if capsTap.needsInputMonitoring {
                    LabeledContent("Input Monitoring") {
                        Button("Open System Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                        }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("Used to change scroll events and, for Caps Lock, to notice whether another key was pressed while it was held. Nothing is recorded or sent anywhere.")
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

            Section {
                Toggle("Caps Lock — tap for Escape, hold for Control", isOn: $settings.capsLockTapEscape)
                LabeledContent("Tap timeout") {
                    HStack {
                        Slider(value: $settings.tapTimeoutMilliseconds, in: 150...1000, step: 50)
                        Text("\(Int(settings.tapTimeoutMilliseconds)) ms").monospacedDigit().frame(width: 60, alignment: .trailing)
                    }
                }
                .disabled(!settings.capsLockTapEscape)
                Toggle("Escape key acts as Caps Lock", isOn: $settings.escapeToCapsLock)
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Caps Lock becomes Control everywhere. Escape on tap needs MenuBarKit running and doesn't fire in password fields, where macOS hides keystrokes from apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
