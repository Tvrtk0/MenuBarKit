import AppKit
import SwiftUI

/// Single-line menu bar text that truncates with "…" past `maxWidth`.
/// SwiftUI won't truncate inside a fixedSize parent (status item labels are), so
/// the width is measured and capped explicitly.
struct MenuBarText: View {
    let text: String
    let maxWidth: CGFloat

    var body: some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: min(Self.width(of: text), maxWidth), alignment: .leading)
    }

    private static func width(of text: String) -> CGFloat {
        let size = (text as NSString).size(withAttributes: [.font: NSFont.menuBarFont(ofSize: 0)])
        return size.width.rounded(.up) + 1
    }
}

/// What a module's status item does when it has nothing to show.
enum IdleBehavior: String, CaseIterable {
    case hide, icon

    var label: String {
        switch self {
        case .hide: "Hide the item"
        case .icon: "Show just the icon"
        }
    }
}
