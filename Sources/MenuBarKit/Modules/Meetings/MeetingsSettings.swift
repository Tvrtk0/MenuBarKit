import Foundation
import Observation

enum MeetingBarElement: String, CaseIterable, Codable {
    case icon, title, timeUntil, startTime

    var label: String {
        switch self {
        case .icon: "Icon"
        case .title: "Meeting title"
        case .timeUntil: "Time until / time left"
        case .startTime: "Start time (14:30)"
        }
    }

    var symbol: String {
        switch self {
        case .icon: "calendar"
        case .title: "textformat"
        case .timeUntil: "hourglass"
        case .startTime: "clock"
        }
    }
}

struct MeetingBarElementConfig: Codable, Equatable {
    var element: MeetingBarElement
    var isEnabled: Bool
}

/// How far ahead a meeting has to be before it shows in the menu bar.
enum MeetingLookahead: Int, CaseIterable {
    case fifteenMinutes = 15
    case oneHour = 60
    case threeHours = 180
    case restOfDay = 0

    var label: String {
        switch self {
        case .fifteenMinutes: "15 minutes before"
        case .oneHour: "1 hour before"
        case .threeHours: "3 hours before"
        case .restOfDay: "Any time that day"
        }
    }
}

@Observable @MainActor
final class MeetingsSettings {
    var elements: [MeetingBarElementConfig] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(elements), forKey: Self.key("elements")) }
    }
    var maxTitleWidth: Double {
        didSet { save(maxTitleWidth, "maxTitleWidth") }
    }
    var lookahead: MeetingLookahead {
        didSet { save(lookahead.rawValue, "lookahead") }
    }
    var idleBehavior: IdleBehavior {
        didSet { save(idleBehavior.rawValue, "idleBehavior") }
    }
    var notify: Bool {
        didSet { save(notify, "notify") }
    }
    /// 0 means "when it starts".
    var notifyMinutesBefore: Int {
        didSet { save(notifyMinutesBefore, "notifyMinutesBefore") }
    }
    var skipAllDay: Bool {
        didSet { save(skipAllDay, "skipAllDay") }
    }
    var skipDeclined: Bool {
        didSet { save(skipDeclined, "skipDeclined") }
    }
    /// Stored as the excluded set so newly added calendars show up by default.
    var hiddenCalendarIDs: Set<String> {
        didSet { save(Array(hiddenCalendarIDs), "hiddenCalendarIDs") }
    }

    var filter: CalendarStore.Filter {
        .init(hiddenCalendarIDs: hiddenCalendarIDs, skipAllDay: skipAllDay, skipDeclined: skipDeclined)
    }

    private static let defaultElements: [MeetingBarElementConfig] = [
        .init(element: .icon, isEnabled: true),
        .init(element: .title, isEnabled: true),
        .init(element: .timeUntil, isEnabled: true),
        .init(element: .startTime, isEnabled: false),
    ]

    init() {
        let defaults = UserDefaults.standard
        var elements = defaults.data(forKey: Self.key("elements"))
            .flatMap { try? JSONDecoder().decode([MeetingBarElementConfig].self, from: $0) } ?? Self.defaultElements
        for element in MeetingBarElement.allCases where !elements.contains(where: { $0.element == element }) {
            elements.append(.init(element: element, isEnabled: false))
        }
        self.elements = elements
        maxTitleWidth = defaults.object(forKey: Self.key("maxTitleWidth")) as? Double ?? 180
        lookahead = (defaults.object(forKey: Self.key("lookahead")) as? Int).flatMap(MeetingLookahead.init) ?? .restOfDay
        idleBehavior = defaults.string(forKey: Self.key("idleBehavior")).flatMap(IdleBehavior.init) ?? .icon
        notify = defaults.object(forKey: Self.key("notify")) as? Bool ?? true
        notifyMinutesBefore = defaults.object(forKey: Self.key("notifyMinutesBefore")) as? Int ?? 1
        skipAllDay = defaults.object(forKey: Self.key("skipAllDay")) as? Bool ?? true
        skipDeclined = defaults.object(forKey: Self.key("skipDeclined")) as? Bool ?? true
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Self.key("hiddenCalendarIDs")) ?? [])
    }

    private func save(_ value: Any, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }

    private static func key(_ name: String) -> String { "meetings.\(name)" }
}
