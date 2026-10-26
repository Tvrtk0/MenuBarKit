import Foundation
import Observation

enum BarElement: String, CaseIterable, Codable {
    case artwork, playState, artist, title, time, progressBar

    var label: String {
        switch self {
        case .artwork: "Album artwork"
        case .playState: "Play / pause icon"
        case .artist: "Artist"
        case .title: "Song title"
        case .time: "Time (2:13/4:23)"
        case .progressBar: "Progress bar"
        }
    }

    var symbol: String {
        switch self {
        case .artwork: "photo"
        case .playState: "play.fill"
        case .artist: "person"
        case .title: "music.note"
        case .time: "clock"
        case .progressBar: "slider.horizontal.below.rectangle"
        }
    }
}

struct BarElementConfig: Codable, Equatable {
    var element: BarElement
    var isEnabled: Bool
}

enum IdleBehavior: String, CaseIterable {
    case hide, icon

    var label: String {
        switch self {
        case .hide: "Hide the item"
        case .icon: "Show a music icon"
        }
    }
}

@Observable @MainActor
final class SpotifySettings {
    /// Order here is the order in the menu bar.
    var elements: [BarElementConfig] {
        didSet { save(elements, "elements") }
    }
    var maxTextWidth: Double {
        didSet { save(maxTextWidth, "maxTextWidth") }
    }
    var progressBarWidth: Double {
        didSet { save(progressBarWidth, "progressBarWidth") }
    }
    var dimWhenPaused: Bool {
        didSet { save(dimWhenPaused, "dimWhenPaused") }
    }
    var idleBehavior: IdleBehavior {
        didSet { save(idleBehavior.rawValue, "idleBehavior") }
    }

    private static let defaultElements: [BarElementConfig] = [
        .init(element: .artwork, isEnabled: true),
        .init(element: .playState, isEnabled: false),
        .init(element: .artist, isEnabled: true),
        .init(element: .title, isEnabled: true),
        .init(element: .time, isEnabled: false),
        .init(element: .progressBar, isEnabled: true),
    ]

    init() {
        let defaults = UserDefaults.standard
        var elements = (defaults.data(forKey: Self.key("elements")))
            .flatMap { try? JSONDecoder().decode([BarElementConfig].self, from: $0) } ?? Self.defaultElements
        // Elements added in later versions show up at the end, switched off.
        for element in BarElement.allCases where !elements.contains(where: { $0.element == element }) {
            elements.append(.init(element: element, isEnabled: false))
        }
        self.elements = elements
        maxTextWidth = defaults.object(forKey: Self.key("maxTextWidth")) as? Double ?? 220
        progressBarWidth = defaults.object(forKey: Self.key("progressBarWidth")) as? Double ?? 50
        dimWhenPaused = defaults.object(forKey: Self.key("dimWhenPaused")) as? Bool ?? true
        idleBehavior = (defaults.string(forKey: Self.key("idleBehavior"))).flatMap(IdleBehavior.init) ?? .hide
    }

    func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard elements.indices.contains(index), elements.indices.contains(target) else { return }
        elements.swapAt(index, target)
    }

    func resetToDefaults() {
        elements = Self.defaultElements
        maxTextWidth = 220
        progressBarWidth = 50
        dimWhenPaused = true
        idleBehavior = .hide
    }

    private func save(_ value: some Any, _ name: String) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }

    private func save(_ value: [BarElementConfig], _ name: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: Self.key(name))
    }

    private static func key(_ name: String) -> String { "spotify.\(name)" }
}
