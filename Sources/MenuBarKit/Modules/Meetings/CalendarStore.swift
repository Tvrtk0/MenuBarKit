import AppKit
import EventKit
import Observation

/// Today's and tomorrow's meetings from the calendars macOS knows about
/// (System Settings ▸ Internet Accounts), via EventKit.
@Observable @MainActor
final class CalendarStore {
    struct Filter: Equatable {
        var hiddenCalendarIDs: Set<String>
        var skipAllDay: Bool
        var skipDeclined: Bool
    }

    struct CalendarInfo: Identifiable, Equatable {
        let id: String
        let title: String
        let account: String
    }

    enum Access {
        case notDetermined, granted, denied
    }

    private(set) var access: Access = .notDetermined
    private(set) var calendars: [CalendarInfo] = []
    /// Sorted by start; from the start of today to the end of tomorrow.
    private(set) var meetings: [Meeting] = []
    /// Ticks every 15 s so relative times ("in 12 min") stay current.
    private(set) var now = Date()

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var filter = Filter(hiddenCalendarIDs: [], skipAllDay: true, skipDeclined: true)
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var lastReload = Date.distantPast

    func start() {
        guard changeObserver == nil else { return }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        updateAccess()
        if access == .notDetermined {
            requestAccess()
        } else {
            reload()
        }
    }

    func stop() {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
        changeObserver = nil
        ticker?.invalidate()
        ticker = nil
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            updateAccess()
            reload()
        }
    }

    func apply(_ filter: Filter) {
        guard filter != self.filter else { return }
        self.filter = filter
        reload()
    }

    func reload() {
        lastReload = Date()
        now = lastReload
        updateAccess()
        guard access == .granted else {
            meetings = []
            calendars = []
            return
        }

        let eventCalendars = store.calendars(for: .event)
        let infos = eventCalendars
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, account: $0.source?.title ?? "Other") }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
        if infos != calendars { calendars = infos }

        let visible = eventCalendars.filter { !filter.hiddenCalendarIDs.contains($0.calendarIdentifier) }
        let dayStart = Calendar.current.startOfDay(for: now)
        let windowEnd = Calendar.current.date(byAdding: .day, value: 2, to: dayStart)!
        let found: [Meeting] = visible.isEmpty ? [] : store
            .events(matching: store.predicateForEvents(withStart: dayStart, end: windowEnd, calendars: visible))
            .filter { event in
                if event.status == .canceled { return false }
                if filter.skipAllDay && event.isAllDay { return false }
                if filter.skipDeclined && Self.isDeclined(event) { return false }
                return true
            }
            .map(Meeting.init(event:))
            .sorted { $0.start < $1.start }
        if found != meetings { meetings = found }
    }

    /// The meeting to show in the menu bar: one in progress, else the next one
    /// today that starts within `lookahead`.
    func barMeeting(lookahead: MeetingLookahead) -> Meeting? {
        if let ongoing = meetings.first(where: { $0.isOngoing(at: now) }) { return ongoing }
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let limit = lookahead == .restOfDay ? dayEnd : now.addingTimeInterval(TimeInterval(lookahead.rawValue * 60))
        return meetings.first { $0.start > now && $0.start < min(limit, dayEnd) }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    private func tick() {
        // Re-query every few minutes as a safety net, and right after midnight.
        let crossedMidnight = !Calendar.current.isDate(lastReload, inSameDayAs: Date())
        if crossedMidnight || Date().timeIntervalSince(lastReload) > 5 * 60 {
            reload()
        } else {
            now = Date()
        }
    }

    private func updateAccess() {
        let newAccess: Access = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
        if newAccess != access { access = newAccess }
    }

    private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }
}
