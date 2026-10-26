import SwiftUI

/// Next meeting in the menu bar, today's list with Join buttons, and a
/// notification before each meeting.
@MainActor
final class MeetingsModule: MenuBarModule {
    let id = "meetings"
    let name = "Meetings"
    let symbol = "calendar"
    /// Off until asked for: it needs calendar access.
    let enabledByDefault = false

    private let settings = MeetingsSettings()
    private let store = CalendarStore()
    private let notifier = MeetingNotifier()
    private var statusItem: StatusItemController?
    private var loops: [ObservationLoop] = []

    func activate() {
        guard statusItem == nil else { return }
        store.apply(settings.filter)
        store.start()

        let item = StatusItemController(
            autosaveName: "MenuBarKit.meetings",
            label: MeetingsBarLabel(store: store, settings: settings),
            popover: AnyView(MeetingsPopover(store: store))
        )
        item.onPopoverWillShow = { [store] in store.reload() }
        statusItem = item

        loops = [
            ObservationLoop { [weak self] in
                guard let self else { return }
                self.store.apply(self.settings.filter)
            },
            ObservationLoop { [weak self] in
                guard let self else { return }
                let hasMeeting = self.store.barMeeting(lookahead: self.settings.lookahead) != nil
                self.statusItem?.isVisible = hasMeeting || self.settings.idleBehavior == .icon
            },
            ObservationLoop { [weak self] in
                guard let self else { return }
                if self.settings.notify {
                    self.notifier.start()
                    self.notifier.schedule(self.store.meetings, minutesBefore: self.settings.notifyMinutesBefore)
                } else {
                    self.notifier.cancelAll()
                }
            },
        ]
    }

    func deactivate() {
        loops.forEach { $0.cancel() }
        loops = []
        statusItem?.remove()
        statusItem = nil
        store.stop()
        notifier.stop()
    }

    func makeSettingsView() -> AnyView {
        AnyView(MeetingsSettingsView(store: store, settings: settings))
    }
}

/// Reads the store inside `body` so SwiftUI re-renders on every observed change.
private struct MeetingsBarLabel: View {
    let store: CalendarStore
    let settings: MeetingsSettings

    var body: some View {
        MeetingBarLabelView(meeting: store.barMeeting(lookahead: settings.lookahead), now: store.now, settings: settings)
    }
}
