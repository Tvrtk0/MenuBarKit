import SwiftUI

struct MeetingsPopover: View {
    let store: CalendarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.access {
            case .granted:
                content
            case .notDetermined:
                accessNotice(button: "Allow calendar access") { store.requestAccess() }
            case .denied:
                accessNotice(button: "Open Privacy settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                }
            }

            Divider()
            HStack {
                Button("Open Calendar") { store.openCalendarApp() }
                Spacer()
                Button {
                    AppServices.shared.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 320)
    }

    @ViewBuilder private var content: some View {
        let calendar = Calendar.current
        let today = store.meetings.filter { calendar.isDate($0.start, inSameDayAs: store.now) }
        let tomorrow = store.meetings.filter { calendar.isDateInTomorrow($0.start) }

        section("Today", meetings: today, empty: "No meetings today")
        if !tomorrow.isEmpty {
            section("Tomorrow", meetings: tomorrow, empty: "")
        }
    }

    private func section(_ title: String, meetings: [Meeting], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if meetings.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            } else {
                ForEach(meetings) { meeting in
                    MeetingRow(meeting: meeting, now: store.now)
                }
            }
        }
    }

    private func accessNotice(button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("MenuBarKit needs access to your calendars", systemImage: "calendar.badge.exclamationmark")
                .font(.headline)
            Text("Meetings are read from the calendars in macOS Calendar (System Settings → Internet Accounts).")
                .font(.callout).foregroundStyle(.secondary)
            Button(button, action: action)
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let now: Date

    var body: some View {
        let ongoing = meeting.isOngoing(at: now)
        let ended = meeting.hasEnded(at: now)
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(meeting.color)
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title).lineLimit(1)
                Text(timeRange + (ongoing || !ended ? " · " + meetingTimeText(meeting, now: now) : ""))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 4)
            if let url = meeting.joinURL, !ended {
                Button("Join") { NSWorkspace.shared.open(url) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(ongoing ? .green : .accentColor)
            }
        }
        .opacity(ended ? 0.45 : 1)
    }

    private var timeRange: String {
        "\(meeting.start.formatted(date: .omitted, time: .shortened))–\(meeting.end.formatted(date: .omitted, time: .shortened))"
    }
}
