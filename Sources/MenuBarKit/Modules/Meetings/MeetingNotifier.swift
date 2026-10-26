import AppKit
import UserNotifications

/// Schedules a "starts in N min" notification per upcoming meeting, with a Join
/// button when the meeting has a call link.
@MainActor
final class MeetingNotifier: NSObject, UNUserNotificationCenterDelegate {
    nonisolated private static let categoryID = "meeting.join"
    nonisolated private static let joinActionID = "join"
    nonisolated private static let idPrefix = "meeting."

    private let center = UNUserNotificationCenter.current()
    private var isStarted = false
    /// Removed by ID rather than by listing pending requests: the listing is
    /// asynchronous and could land after (and delete) freshly scheduled ones.
    private var scheduledIDs: [String] = []

    func start() {
        guard !isStarted else { return }
        isStarted = true
        center.delegate = self
        // Drop leftovers from a previous run; this app only schedules meeting reminders.
        center.removeAllPendingNotificationRequests()
        let join = UNNotificationAction(identifier: Self.joinActionID, title: "Join", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: [join], intentIdentifiers: [])
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func stop() {
        cancelAll()
    }

    /// Replaces every pending meeting notification with ones for `meetings`.
    func schedule(_ meetings: [Meeting], minutesBefore: Int) {
        cancelAll()
        let now = Date()
        let lead = TimeInterval(minutesBefore * 60)
        for meeting in meetings {
            let fireDate = meeting.start.addingTimeInterval(-lead)
            // Only the next day's worth; the list is refreshed long before then.
            guard fireDate > now, fireDate < now.addingTimeInterval(24 * 60 * 60) else { continue }

            let content = UNMutableNotificationContent()
            content.title = meeting.title
            content.body = minutesBefore == 0
                ? "Starting now"
                : "Starts in \(minutesBefore) min at \(meeting.start.formatted(date: .omitted, time: .shortened))"
            content.sound = .default
            if let url = meeting.joinURL {
                content.categoryIdentifier = Self.categoryID
                content.userInfo = ["url": url.absoluteString]
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSince(now), repeats: false)
            let id = Self.idPrefix + meeting.id
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            scheduledIDs.append(id)
        }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: scheduledIDs)
        scheduledIDs.removeAll()
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// Both the Join button and a click on the notification itself open the call.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isOpen = response.actionIdentifier == Self.joinActionID
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        if isOpen,
           let link = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: link) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
