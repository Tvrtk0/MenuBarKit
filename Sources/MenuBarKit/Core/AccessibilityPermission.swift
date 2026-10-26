import AppKit
import ApplicationServices
import Observation

/// Accessibility (a.k.a. "control your computer") permission, needed by any module
/// that watches or rewrites input events. macOS posts no notification when it's
/// granted or revoked, so this polls while a module needs it.
@Observable @MainActor
final class AccessibilityPermission {
    private(set) var isGranted = AXIsProcessTrusted()

    @ObservationIgnored private var timer: Timer?

    func startMonitoring() {
        guard timer == nil else { return }
        isGranted = AXIsProcessTrusted()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let granted = AXIsProcessTrusted()
                if granted != self.isGranted { self.isGranted = granted }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Shows the system prompt that links to System Settings (only the first time).
    func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isGranted = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
