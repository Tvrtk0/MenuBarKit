import AppKit
import IOKit
import IOKit.hid

/// System-wide key remapping through `hidutil` — the same mechanism as the
/// Keyboard ▸ Modifier Keys setting, so it needs no permission and works in every
/// app, password fields included. It lasts until reboot or until cleared.
@MainActor
final class KeyRemapper {
    struct Mapping: Equatable {
        let source: UInt64
        let destination: UInt64
    }

    // HID usage IDs (page 7, keyboard) as hidutil expects them.
    static let capsLock: UInt64 = 0x7_0000_0039
    static let escape: UInt64 = 0x7_0000_0029
    static let rightControl: UInt64 = 0x7_0000_00E4

    private var mappings: [Mapping] = []
    private var notifyPort: IONotificationPortRef?
    private var iterator: io_iterator_t = 0
    private var wakeObservers: [NSObjectProtocol] = []

    func apply(_ mappings: [Mapping]) {
        guard mappings != self.mappings else { return }
        self.mappings = mappings
        push()
        if mappings.isEmpty {
            stopWatchingKeyboards()
            stopWatchingWake()
        } else {
            startWatchingKeyboards()
            startWatchingWake()
        }
    }

    func clear() {
        apply([])
    }

    private func push() {
        let entries = mappings.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.source),\"HIDKeyboardModifierMappingDst\":\($0.destination)}"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", "{\"UserKeyMapping\":[\(entries.joined(separator: ","))]}"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: Keyboards plugged in later

    /// A keyboard attached after the mapping was set may not pick it up, so
    /// re-apply whenever one appears. Registry notifications need no permission.
    private func startWatchingKeyboards() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        let matching = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary
        matching[kIOHIDDeviceUsagePageKey] = kHIDPage_GenericDesktop
        matching[kIOHIDDeviceUsageKey] = kHIDUsage_GD_Keyboard
        IOServiceAddMatchingNotification(
            port, kIOFirstMatchNotification, matching,
            keyboardAddedCallback, Unmanaged.passUnretained(self).toOpaque(), &iterator
        )
        drain(iterator)  // arms the notification; existing keyboards are already covered
        notifyPort = port
    }

    private func stopWatchingKeyboards() {
        if iterator != 0 {
            IOObjectRelease(iterator)
            iterator = 0
        }
        if let notifyPort {
            IONotificationPortDestroy(notifyPort)
        }
        notifyPort = nil
    }

    // MARK: Wake and session switches

    /// macOS re-applies its own Modifier Keys settings on wake and when the user
    /// session becomes active again, which can overwrite these mappings.
    private func startWatchingWake() {
        guard wakeObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            wakeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reapplySoon() }
            })
        }
    }

    private func stopWatchingWake() {
        for observer in wakeObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        wakeObservers.removeAll()
    }

    /// Re-applies the mappings shortly after a keyboard appears or the Mac wakes.
    fileprivate func reapplySoon() {
        Task {
            // Give the new device a moment to register before mapping it.
            try? await Task.sleep(for: .seconds(1))
            if !mappings.isEmpty { push() }
        }
    }
}

private func drain(_ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
    }
}

private func keyboardAddedCallback(refcon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    drain(iterator)
    guard let refcon else { return }
    let remapper = Unmanaged<KeyRemapper>.fromOpaque(refcon).takeUnretainedValue()
    // Delivered on the main queue (see IONotificationPortSetDispatchQueue).
    MainActor.assumeIsolated { remapper.reapplySoon() }
}
