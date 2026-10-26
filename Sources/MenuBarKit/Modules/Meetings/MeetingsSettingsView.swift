import SwiftUI

struct MeetingsSettingsView: View {
    let store: CalendarStore
    @Bindable var settings: MeetingsSettings

    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Spacer()
                    MeetingBarLabelView(
                        meeting: store.barMeeting(lookahead: settings.lookahead) ?? .sample(now: store.now),
                        now: store.now, settings: settings
                    )
                    .fixedSize()
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                    Spacer()
                }
            }

            if store.access != .granted {
                Section {
                    LabeledContent("Calendar access") {
                        if store.access == .notDetermined {
                            Button("Allow") { store.requestAccess() }
                        } else {
                            Button("Open System Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                            }
                        }
                    }
                }
            }

            Section {
                ElementOrderRows(items: $settings.elements, isEnabled: \.isEnabled,
                                 label: \.element.label, symbol: \.element.symbol)
            } header: {
                Text("Shown in the menu bar")
            } footer: {
                Text("Top to bottom is left to right. While a meeting is on, the time shows how much is left.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                LabeledContent("Max title width") {
                    HStack {
                        Slider(value: $settings.maxTitleWidth, in: 60...400, step: 10)
                        Text("\(Int(settings.maxTitleWidth)) pt").monospacedDigit().frame(width: 50, alignment: .trailing)
                    }
                }
                Picker("Show the next meeting", selection: $settings.lookahead) {
                    ForEach(MeetingLookahead.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("When there's no meeting", selection: $settings.idleBehavior) {
                    ForEach(IdleBehavior.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }

            Section {
                Toggle("Notify before a meeting starts", isOn: $settings.notify)
                Picker("When", selection: $settings.notifyMinutesBefore) {
                    Text("When it starts").tag(0)
                    ForEach([1, 2, 5, 10, 15], id: \.self) { Text("\($0) min before").tag($0) }
                }
                .disabled(!settings.notify)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Meetings with a Meet, Zoom, Teams or Webex link get a Join button. If nothing shows up, allow MenuBarKit in System Settings → Notifications.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Filter") {
                Toggle("Skip all-day events", isOn: $settings.skipAllDay)
                Toggle("Skip events I declined", isOn: $settings.skipDeclined)
            }

            if !store.calendars.isEmpty {
                Section("Calendars") {
                    ForEach(store.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { !settings.hiddenCalendarIDs.contains(calendar.id) },
                            set: { shown in
                                if shown {
                                    settings.hiddenCalendarIDs.remove(calendar.id)
                                } else {
                                    settings.hiddenCalendarIDs.insert(calendar.id)
                                }
                            }
                        )) {
                            Text(calendar.title)
                            Text(calendar.account)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
