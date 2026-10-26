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

    var scrollOptions: ScrollReverser.Options {
        .init(mouseVertical: reverseMouseVertical, mouseHorizontal: reverseMouseHorizontal, trackpad: reverseTrackpad)
    }

    init() {
        let defaults = UserDefaults.standard
        reverseMouseVertical = defaults.object(forKey: Self.key("reverseMouseVertical")) as? Bool ?? true
        reverseMouseHorizontal = defaults.object(forKey: Self.key("reverseMouseHorizontal")) as? Bool ?? true
        reverseTrackpad = defaults.object(forKey: Self.key("reverseTrackpad")) as? Bool ?? false
    }

    private func save(_ value: Bool, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }

    private static func key(_ name: String) -> String { "input.\(name)" }
}
