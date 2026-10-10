import AppKit

private final class CPSPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class CPSOverlayController {
    private(set) var panel: NSPanel
    private let valueLabel = NSTextField(labelWithString: "0.0")

    init() {
        panel = CPSPanel(contentRect: NSRect(x: 0, y: 0, width: 150, height: 72),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let background = NSVisualEffectView(frame: panel.contentView!.bounds)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        panel.contentView = background

        let title = NSTextField(labelWithString: "Actual CPS")
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        valueLabel.textColor = .systemGreen
        valueLabel.setAccessibilityLabel("Actual CPS")
        let stack = NSStackView(views: [title, valueLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor)
        ])
    }

    func show() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) else { return }
        update(0)
        panel.setFrame(Self.frame(near: pointer, within: screen.visibleFrame), display: true)
        panel.orderFrontRegardless()
    }

    func update(_ cps: Double) {
        valueLabel.stringValue = String(format: "%.1f", cps)
    }

    func hide() { panel.orderOut(nil) }

    static func frame(near pointer: NSPoint, within bounds: NSRect) -> NSRect {
        let size = NSSize(width: 150, height: 72)
        let gap: CGFloat = 20
        var x = pointer.x + gap
        var y = pointer.y - gap - size.height
        if x + size.width > bounds.maxX { x = pointer.x - gap - size.width }
        if y < bounds.minY { y = pointer.y + gap }
        x = max(bounds.minX, min(x, bounds.maxX - size.width))
        y = max(bounds.minY, min(y, bounds.maxY - size.height))
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}
