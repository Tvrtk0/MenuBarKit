import Foundation
import Observation

@Observable @MainActor
final class InputSettings {
    var reverseMouseVertical: Bool {
        didSet { save(reverseMouseVertical, "reverseMouseVertical") }
    }
    var reverseMouseHorizontal: Bool {
        didSet { save(reverseMouseHorizontal, "reverseMouseHorizontal") }
    }
    var reverseTrackpad: Bool {
        didSet { save(reverseTrackpad, "reverseTrackpad") }
    }
    var capsLockTapEscape: Bool {
        didSet { save(capsLockTapEscape, "capsLockTapEscape") }
    }
    var escapeToCapsLock: Bool {
        didSet { save(escapeToCapsLock, "escapeToCapsLock") }
    }
    /// Longest press of Caps Lock that still counts as a tap, in milliseconds.
    var tapTimeoutMilliseconds: Double {
        didSet { save(tapTimeoutMilliseconds, "tapTimeoutMilliseconds") }
    }

    var scrollOptions: ScrollReverser.Options {
        .init(mouseVertical: reverseMouseVertical, mouseHorizontal: reverseMouseHorizontal, trackpad: reverseTrackpad)
    }

    var keyMappings: [KeyRemapper.Mapping] {
        var mappings: [KeyRemapper.Mapping] = []
        if capsLockTapEscape {
            mappings.append(.init(source: KeyRemapper.capsLock, destination: KeyRemapper.rightControl))
        }
        if escapeToCapsLock {
            mappings.append(.init(source: KeyRemapper.escape, destination: KeyRemapper.capsLock))
        }
        return mappings
    }

    init() {
        let defaults = UserDefaults.standard
        reverseMouseVertical = defaults.object(forKey: Self.key("reverseMouseVertical")) as? Bool ?? true
        reverseMouseHorizontal = defaults.object(forKey: Self.key("reverseMouseHorizontal")) as? Bool ?? true
        reverseTrackpad = defaults.object(forKey: Self.key("reverseTrackpad")) as? Bool ?? false
        capsLockTapEscape = defaults.object(forKey: Self.key("capsLockTapEscape")) as? Bool ?? false
        escapeToCapsLock = defaults.object(forKey: Self.key("escapeToCapsLock")) as? Bool ?? false
        tapTimeoutMilliseconds = defaults.object(forKey: Self.key("tapTimeoutMilliseconds")) as? Double ?? 500
    }

    private func save(_ value: Any, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }

    private static func key(_ name: String) -> String { "input.\(name)" }
}
