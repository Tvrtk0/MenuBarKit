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
                ForEach(Array(settings.elements.enumerated()), id: \.element.element) { index, config in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { settings.elements[index].isEnabled },
                            set: { settings.elements[index].isEnabled = $0 }
                        )) {
                            Label(config.element.label, systemImage: config.element.symbol)
                        }
                        .toggleStyle(.checkbox)
                        Spacer()
                        Button { settings.move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(index == 0)
                        Button { settings.move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(index == settings.elements.count - 1)
                    }
                    .buttonStyle(.borderless)
                }
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
