import AppKit

// Visual smoke test: exercise the real timer and overlay without posting mouse input.
@main
struct OverlayPreview {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let overlay = CPSOverlayController()
        let clicker = MouseClicker(clickAction: { _ in true }, startSound: {})
        var latestCPS = 0.0
        clicker.onRunningChanged = { $0 ? overlay.show() : overlay.hide() }
        clicker.onActualCPSChanged = { latestCPS = $0; overlay.update($0) }
        let preset = ClickScheme(name: "Overlay preview", button: .left, targetCPS: 100,
                                 totalDuration: 1, hotkey: Hotkey(keyCode: 18), isUnlimited: true)
        let previousFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        clicker.executeScheme(preset)
        precondition(overlay.panel.isVisible && overlay.panel.ignoresMouseEvents)
        precondition(!overlay.panel.canBecomeKey && !overlay.panel.canBecomeMain)
        precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == previousFrontmost,
                     "Overlay must not activate ClickLoop")
        print("Preview: real timer, in-memory clicks; no mouse events are posted.")
        RunLoop.main.run(until: Date().addingTimeInterval(40))
        precondition(latestCPS > 0 && latestCPS <= 200, "Measured preview rate: \(latestCPS)")
        clicker.stop()
        precondition(!overlay.panel.isVisible && latestCPS == 0)
        var slower = preset
        slower.targetCPS = 10
        clicker.executeScheme(slower)
        precondition(latestCPS == 0 && overlay.panel.isVisible)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        precondition(latestCPS < 15, "Restart must not reuse the previous run's samples")
        clicker.stop()
        print("PASS: overlay appears, preserves focus, measures CPS, hides and resets on restart.")
    }
}
