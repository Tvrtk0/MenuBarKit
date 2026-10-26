import CoreGraphics
import Foundation
import Observation

/// Sends Escape when Caps Lock is tapped on its own. Caps Lock itself is remapped
/// to Right Control by `KeyRemapper`, so holding it is plain Control even when this
/// tap can't see keys (password fields); this only adds the tap-alone Escape.
@Observable @MainActor
final class CapsTapEscape {
    /// True when macOS refused the tap — then Input Monitoring is needed as well.
    private(set) var needsInputMonitoring = false

    var timeout: TimeInterval {
        get { context.timeout }
        set { context.timeout = newValue }
    }

    @ObservationIgnored private let context = CapsTapContext()
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var retryTimer: Timer?

    func start() {
        guard context.tap == nil else { return }
        if createTap() {
            needsInputMonitoring = false
            retryTimer?.invalidate()
            retryTimer = nil
        } else if retryTimer == nil {
            needsInputMonitoring = true
            CGRequestListenEventAccess()
            // Pick it up as soon as the permission is granted.
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.start() }
            }
            RunLoop.main.add(timer, forMode: .common)
            retryTimer = timer
        }
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap = context.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        context.tap = nil
        context.pressedAt = nil
        runLoopSource = nil
    }

    private func createTap() -> Bool {
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << $1.rawValue }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: capsTapCallback,
            userInfo: Unmanaged.passUnretained(context).toOpaque()
        ) else { return false }
        context.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}

/// State the C callback reads. Only touched on the main run loop.
private final class CapsTapContext {
    var tap: CFMachPort?
    var timeout: TimeInterval = 0.5
    /// Set while Caps Lock (Right Control) is held.
    var pressedAt: UInt64?
    /// Anything else happened while it was held — it was used as Control.
    var interrupted = false
}

private let rightControlKeyCode: Int64 = 62  // kVK_RightControl
private let escapeKeyCode: CGKeyCode = 53  // kVK_Escape
private let rightControlFlag: UInt64 = 0x2000  // NX_DEVICERCTLKEYMASK

private func capsTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return .passUnretained(event) }
    let context = Unmanaged<CapsTapContext>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap = context.tap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .flagsChanged where event.getIntegerValueField(.keyboardEventKeycode) == rightControlKeyCode:
        let now = DispatchTime.now().uptimeNanoseconds
        if event.flags.rawValue & rightControlFlag != 0 {
            context.pressedAt = now
            context.interrupted = false
        } else if let pressedAt = context.pressedAt {
            context.pressedAt = nil
            let held = TimeInterval(now - pressedAt) / 1_000_000_000
            if !context.interrupted && held <= context.timeout {
                postEscape()
            }
        }
    default:
        if context.pressedAt != nil { context.interrupted = true }
    }
    return .passUnretained(event)
}

/// Posted below the HID remap, so this stays Escape even though the physical
/// Escape key may be mapped to Caps Lock.
private func postEscape() {
    let source = CGEventSource(stateID: .hidSystemState)
    for keyDown in [true, false] {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: escapeKeyCode, keyDown: keyDown) else { continue }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }
}
