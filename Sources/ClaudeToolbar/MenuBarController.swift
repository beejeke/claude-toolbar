import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    let viewModel: UsageViewModel
    private var eventMonitor: Any?

    init() {
        viewModel = UsageViewModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true

        let hostingController = NSHostingController(
            rootView: ContentView()
                .environmentObject(viewModel)
        )
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 340, height: hostingController.view.fittingSize.height)

        if let button = statusItem.button {
            button.image = Self.makeClaudeLogoImage(size: 18)
            button.target = self
            button.action = #selector(handleClick)
        }
    }

    // MARK: - Toggle

    @objc private func handleClick() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        viewModel.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentSize = NSSize(width: 320, height: 280)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in self?.closePopover() }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Claude logo as NSImage (isTemplate adapta dark/light mode)

    static func makeClaudeLogoImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let cx = rect.midX
            let cy = rect.midY
            let armLength = size * 0.44
            let armWidth  = size * 0.175

            NSColor.labelColor.setFill()

            for i in 0..<4 {
                let angle = CGFloat(i) * .pi / 4
                let transform = NSAffineTransform()
                transform.translateX(by: cx, yBy: cy)
                transform.rotate(byRadians: angle)

                let capsuleRect = NSRect(
                    x: -armWidth / 2,
                    y: -armLength,
                    width: armWidth,
                    height: armLength * 2
                )
                let path = NSBezierPath(
                    roundedRect: capsuleRect,
                    xRadius: armWidth / 2,
                    yRadius: armWidth / 2
                )
                path.transform(using: transform as AffineTransform)
                path.fill()
            }
            return true
        }
        image.isTemplate = true   // Adaptacion automatica dark/light mode
        return image
    }
}
