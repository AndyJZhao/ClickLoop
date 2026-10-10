import Foundation
import CoreGraphics
import AppKit

/// UI methods run on the main thread; the serial queue owns the click timer.
class MouseClicker {
    private let queue = DispatchQueue(label: "ClickLoop.clicks", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var runID: UUID?
    private var activity: NSObjectProtocol?
    private(set) var activeSchemeID: UUID?
    var onRunningChanged: ((Bool) -> Void)?
    private let clickAction: (MouseButton) -> Void
    private let startSound: () -> Void

    init(clickAction: @escaping (MouseButton) -> Void = MouseClicker.simulateClick,
         startSound: @escaping () -> Void = { NSSound(named: "Tink")?.play() }) {
        self.clickAction = clickAction
        self.startSound = startSound
    }

    func executeScheme(_ scheme: ClickScheme) {
        stop()
        guard ClickScheme.isValidTiming(targetCPS: scheme.targetCPS,
                                        duration: scheme.totalDuration) else { return }
        let runID = UUID()
        self.runID = runID
        activeSchemeID = scheme.id
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "User-requested automatic clicking")
        onRunningChanged?(true)
        startSound()
        let clickAction = self.clickAction
        queue.sync {
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
            var remaining = scheme.clickCount
            timer.schedule(deadline: .now(), repeating: scheme.clickInterval, leeway: .nanoseconds(0))
            timer.setEventHandler { [weak self] in
                clickAction(scheme.button)
                if !scheme.isUnlimited {
                    remaining -= 1
                    if remaining == 0 {
                        self?.timer?.cancel()
                        DispatchQueue.main.async { [weak self] in
                            guard self?.runID == runID else { return }
                            self?.stop()
                        }
                    }
                }
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        // Wait only for an in-flight down/up pair, never for the next click interval.
        queue.sync {
            timer?.cancel()
            timer = nil
        }
        runID = nil
        activeSchemeID = nil
        if let activity = activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        onRunningChanged?(false)
    }

    deinit {
        timer?.cancel()
        if let activity = activity { ProcessInfo.processInfo.endActivity(activity) }
    }

    static func clickEvents(button: MouseButton, at location: CGPoint) -> (CGEvent, CGEvent)? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        source.localEventsSuppressionInterval = 0
        guard let down = CGEvent(mouseEventSource: source, mouseType: button.downEventType,
                                 mouseCursorPosition: location, mouseButton: button == .left ? .left : .right),
              let up = CGEvent(mouseEventSource: source, mouseType: button.upEventType,
                               mouseCursorPosition: location, mouseButton: button == .left ? .left : .right)
        else { return nil }
        // Holding the trigger shortcut must not turn clicks into Control/Command-clicks.
        for event in [down, up] {
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        down.setDoubleValueField(.mouseEventPressure, value: 1)
        up.setDoubleValueField(.mouseEventPressure, value: 0)
        return (down, up)
    }

    static func simulateClick(button: MouseButton) {
        guard let location = CGEvent(source: nil)?.location,
              let (down, up) = clickEvents(button: button, at: location) else { return }
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.001)
        up.post(tap: .cghidEventTap)
    }
}
