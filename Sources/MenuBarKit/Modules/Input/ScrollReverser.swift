import CoreGraphics
import Foundation

/// Flips scroll direction per source via a session event tap. Requires the
/// Accessibility permission (an active tap may modify events).
@MainActor
final class ScrollReverser {
    struct Options: Equatable {
        var mouseVertical: Bool
        var mouseHorizontal: Bool
        var trackpad: Bool

        var flipsAnything: Bool { mouseVertical || mouseHorizontal || trackpad }
    }

    private let context = ScrollTapContext()
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { context.tap != nil }

    func apply(_ options: Options) {
        context.options = options
        if options.flipsAnything {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        if let tap = context.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        context.tap = nil
        runLoopSource = nil
    }

    private func start() {
        guard context.tap == nil else { return }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: Unmanaged.passUnretained(context).toOpaque()
        ) else { return }  // nil when Accessibility isn't granted
        context.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

/// State the C callback reads. Only touched on the main run loop, where the tap's
/// source is scheduled.
private final class ScrollTapContext {
    var options = ScrollReverser.Options(mouseVertical: false, mouseHorizontal: false, trackpad: false)
    var tap: CFMachPort?
}

private func scrollTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return .passUnretained(event) }
    let context = Unmanaged<ScrollTapContext>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // macOS switches a tap off if a callback ever stalls; switch it straight back on.
        if let tap = context.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return .passUnretained(event)
    case .scrollWheel:
        break
    default:
        return .passUnretained(event)
    }

    // Trackpads (and the Magic Mouse) report gesture phases; wheels never do —
    // even smooth-scrolling ones, which also set the "continuous" flag.
    let isTrackpad = event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
        || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    let options = context.options
    if isTrackpad ? options.trackpad : options.mouseVertical {
        negate(event, .scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1)
    }
    if isTrackpad ? options.trackpad : options.mouseHorizontal {
        negate(event, .scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)
    }
    return .passUnretained(event)
}

/// Each axis is stored three ways (lines, fixed-point lines, pixels); apps read
/// different ones, so all three must flip together.
private func negate(_ event: CGEvent, _ delta: CGEventField, _ fixedPoint: CGEventField, _ point: CGEventField) {
    let fixed = event.getDoubleValueField(fixedPoint)
    let pixels = event.getIntegerValueField(point)
    event.setIntegerValueField(delta, value: -event.getIntegerValueField(delta))
    event.setDoubleValueField(fixedPoint, value: -fixed)
    event.setIntegerValueField(point, value: -pixels)
}
