import AppKit
import SwiftUI

/// One menu bar item whose label is a SwiftUI view. Left click opens the popover
/// (or the menu when there is none); right click or ⌃-click always opens the menu.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    var onPopoverWillShow: (() -> Void)?

    var isVisible: Bool {
        get { item.isVisible }
        set { if item.isVisible != newValue { item.isVisible = newValue } }
    }

    private let item: NSStatusItem
    private let popover: NSPopover?

    init<Label: View>(autosaveName: String, label: Label, popover content: AnyView? = nil) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        if let content {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: content)
            self.popover = popover
        } else {
            popover = nil
        }
        super.init()
        popover?.delegate = self

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let host = LabelHostingView(rootView: label
            .fixedSize()
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity))
        host.sizingOptions = [.intrinsicContentSize]
        host.autoresizingMask = [.height]
        host.onSizeChange = { [weak self, weak host] in
            guard let self, let host, let button = self.item.button else { return }
            let width = host.fittingSize.width.rounded(.up)
            host.frame = NSRect(x: 0, y: 0, width: width, height: button.bounds.height)
            if self.item.length != width { self.item.length = width }
        }
        button.addSubview(host)
        host.onSizeChange?()
    }

    func remove() {
        popover?.close()
        NSStatusBar.system.removeStatusItem(item)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = popover == nil
            || event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let popover, let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        onPopoverWillShow?()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate()
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        item.button?.highlight(false)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MenuBarKit", action: #selector(quit), keyEquivalent: "q").target = self
        // Attaching the menu only for this click keeps left click free for the popover.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openSettings() {
        AppServices.shared.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Hosts a status item label: reports every content size change so the item can
/// resize to fit, and lets clicks fall through to the status bar button underneath.
private final class LabelHostingView<Content: View>: NSHostingView<Content> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // Deferred: SwiftUI invalidates mid-update, before the new size is measurable.
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension Font {
    static let menuBar = Font(NSFont.menuBarFont(ofSize: 0))
}
