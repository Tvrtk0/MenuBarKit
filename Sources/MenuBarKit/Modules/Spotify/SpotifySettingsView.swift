import SwiftUI

struct SpotifySettingsView: View {
    let player: SpotifyPlayer
    @Bindable var settings: SpotifySettings

    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Spacer()
                    BarLabelView(nowPlaying: player.track == nil ? .sample : player.nowPlaying, settings: settings)
                        .fixedSize()
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    Spacer()
                }
            }

            Section {
                ElementOrderRows(items: $settings.elements, isEnabled: \.isEnabled,
                                 label: \.element.label, symbol: \.element.symbol)
            } header: {
                Text("Shown in the menu bar")
            } footer: {
                Text("Top to bottom is left to right. Artist and title next to each other are joined as “Artist – Title”.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                LabeledContent("Max text width") {
                    HStack {
                        Slider(value: $settings.maxTextWidth, in: 60...500, step: 10)
                        Text("\(Int(settings.maxTextWidth)) pt").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                }
                LabeledContent("Progress bar width") {
                    HStack {
                        Slider(value: $settings.progressBarWidth, in: 20...200, step: 5)
                        Text("\(Int(settings.progressBarWidth)) pt").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                }
                Toggle("Dim when paused", isOn: $settings.dimWhenPaused)
            }

            Section("When nothing is playing") {
                Picker("Menu bar item", selection: $settings.idleBehavior) {
                    ForEach(IdleBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.label).tag(behavior)
                    }
                }
            }

            Section {
                Button("Reset to defaults") { settings.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
    }
}
