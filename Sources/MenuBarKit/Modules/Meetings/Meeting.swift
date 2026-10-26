import EventKit
import SwiftUI

struct Meeting: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: Color
    let joinURL: URL?

    func isOngoing(at now: Date) -> Bool { start <= now && now < end }
    func hasEnded(at now: Date) -> Bool { end <= now }

    init(event: EKEvent) {
        // eventIdentifier repeats across occurrences of a recurring event.
        id = "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSince1970)"
        title = event.title?.isEmpty == false ? event.title : "Untitled"
        start = event.startDate
        end = event.endDate
        color = Color(nsColor: event.calendar?.color ?? .systemGray)
        joinURL = MeetingLink.find(in: event)
    }

    init(id: String, title: String, start: Date, end: Date, color: Color, joinURL: URL?) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.color = color
        self.joinURL = joinURL
    }

    static func sample(now: Date = Date()) -> Meeting {
        Meeting(id: "sample", title: "Weekly sync", start: now.addingTimeInterval(12 * 60),
                end: now.addingTimeInterval(42 * 60), color: .blue,
                joinURL: URL(string: "https://meet.google.com/abc-defg-hij"))
    }
}

/// Finds the video call link in an event: its URL field first, then the
/// location, then the notes (where Google Calendar puts the Meet link).
enum MeetingLink {
    private static let pattern = try! NSRegularExpression(pattern: [
        #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#,
        #"https://(?:[\w-]+\.)?zoom\.us/(?:j|my|w)/[^\s"<>]+"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+"#,
        #"https://teams\.live\.com/meet/[^\s"<>]+"#,
        #"https://(?:[\w-]+\.)?webex\.com/[^\s"<>]+"#,
        #"https://whereby\.com/[^\s"<>]+"#,
        #"https://(?:www\.)?around\.co/[^\s"<>]+"#,
    ].joined(separator: "|"), options: .caseInsensitive)

    static func find(in event: EKEvent) -> URL? {
        let texts = [event.url?.absoluteString, event.location, event.notes]
        for text in texts.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, range: range),
               let swiftRange = Range(match.range, in: text) {
                return URL(string: String(text[swiftRange]))
            }
        }
        return nil
    }
}

/// "in 12 min", "in 1 h 5 min", "now", or "12 min left" while it's on.
func meetingTimeText(_ meeting: Meeting, now: Date) -> String {
    if meeting.isOngoing(at: now) {
        return "\(durationText(meeting.end.timeIntervalSince(now))) left"
    }
    let until = meeting.start.timeIntervalSince(now)
    return until < 60 ? "now" : "in \(durationText(until))"
}

private func durationText(_ interval: TimeInterval) -> String {
    let minutes = max(1, Int((interval / 60).rounded(.up)))
    if minutes < 60 { return "\(minutes) min" }
    let (hours, rest) = (minutes / 60, minutes % 60)
    return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
}
