import SwiftUI

/// The Meetings item's menu bar label, built from the enabled elements in order.
struct MeetingBarLabelView: View {
    let meeting: Meeting?
    let now: Date
    let settings: MeetingsSettings

    var body: some View {
        Group {
            if let meeting, !enabledElements.isEmpty {
                HStack(spacing: 5) {
                    ForEach(enabledElements, id: \.self) { element in
                        view(for: element, meeting: meeting)
                    }
                }
            } else {
                Image(systemName: "calendar")
            }
        }
        .font(.menuBar)
    }

    private var enabledElements: [MeetingBarElement] {
        settings.elements.filter(\.isEnabled).map(\.element)
    }

    @ViewBuilder private func view(for element: MeetingBarElement, meeting: Meeting) -> some View {
        switch element {
        case .icon:
            Image(systemName: meeting.joinURL == nil ? "calendar" : "video")
        case .title:
            MenuBarText(text: meeting.title, maxWidth: settings.maxTitleWidth)
        case .timeUntil:
            Text(meetingTimeText(meeting, now: now)).monospacedDigit()
        case .startTime:
            Text(meeting.start.formatted(date: .omitted, time: .shortened)).monospacedDigit()
        }
    }
}
