import Foundation
import CoreGraphics

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    print("PASS: \(message)")
}

func runLoop(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

func scheme(count: Int = 3, duration: Double = 0.06, unlimited: Bool = false,
            button: MouseButton = .left) -> ClickScheme {
    ClickScheme(name: "Test", button: button, clickCount: count,
                totalDuration: duration, hotkey: Hotkey(keyCode: 18, optionKey: true),
                isUnlimited: unlimited)
}

check(ClickScheme.isValidTiming(clickCount: 10, duration: 600), "600-second duration accepted")
check(ClickScheme.isValidTiming(clickCount: 10, duration: 86400), "24-hour duration accepted")
check(ClickScheme.isValidTiming(clickCount: 200, duration: 1), "200 CPS accepted")
for duration in [0.0, -1.0, Double.nan, Double.infinity, 0.001] {
    check(!ClickScheme.isValidTiming(clickCount: 1, duration: duration), "invalid duration rejected: \(duration)")
}
check(!ClickScheme.isValidTiming(clickCount: 201, duration: 1), "over 200 CPS rejected")
check(!ClickScheme.isValidTiming(clickCount: 0, duration: 1), "zero count rejected")
check(scheme(count: 1, duration: 5, unlimited: true).clickInterval == 5, "one-click infinite rate preserved")

// Substitute an in-memory sink: these tests never send mouse events or need Accessibility.
final class ClickLog {
    private let lock = NSLock()
    private var values: [(MouseButton, Double)] = []
    func append(_ button: MouseButton) {
        lock.lock(); defer { lock.unlock() }
        values.append((button, ProcessInfo.processInfo.systemUptime))
    }
    var snapshot: [(MouseButton, Double)] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
    func reset() { lock.lock(); values = []; lock.unlock() }
}
let log = ClickLog()
var events: [MouseButton] { log.snapshot.map { $0.0 } }
var running = false
let clicker = MouseClicker(clickAction: { log.append($0) }, startSound: {})
clicker.onRunningChanged = { running = $0 }
clicker.executeScheme(scheme())
runLoop(0.15)
check(events.count == 3 && !running, "finite execution stops at the requested count")

log.reset()
clicker.executeScheme(scheme(count: 1, duration: 0.02, unlimited: true))
runLoop(0.12)
check(events.count >= 4 && running, "infinite execution continues past the configured count")
clicker.stop()
let stoppedCount = events.count
runLoop(0.06)
check(events.count == stoppedCount && !running, "stop cancels future clicks")

log.reset()
clicker.executeScheme(scheme(count: 2, duration: 600))
runLoop(0.02)
check(events.count == 1 && running, "long duration starts immediately")
let beforeStop = Date()
clicker.stop()
check(Date().timeIntervalSince(beforeStop) < 0.1 && !running, "long interval cancels immediately")
runLoop(0.03)
check(events.count == 1, "cancelled long run produces no extra clicks")

log.reset()
clicker.executeScheme(scheme(count: 1, duration: 0.02, unlimited: true))
runLoop(0.005)
clicker.executeScheme(scheme(count: 2, duration: 0.04, button: .right))
runLoop(0.12)
check(events == [.left, .right, .right] && !running, "replacing a run cancels the previous timer")

clicker.executeScheme(scheme(count: 0))
check(!running, "invalid configuration never starts")

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let storage = SchemeManager(directoryURL: directory)
let saved = scheme(count: 10, duration: 600, unlimited: true)
_ = storage.addScheme(saved)
let reloaded = SchemeManager(directoryURL: directory).getAllSchemes()
check(reloaded.contains(saved), "unlimited mode, duration and UUID survive persistence")

// Older SnapClick-format records have no isUnlimited property.
let path = directory.appendingPathComponent("schemes.json")
var records = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [[String: Any]]
for index in records.indices { records[index].removeValue(forKey: "isUnlimited") }
try JSONSerialization.data(withJSONObject: records).write(to: path)
let legacy = SchemeManager(directoryURL: directory).getAllSchemes()
check(legacy.count == records.count && legacy.allSatisfy { !$0.isUnlimited }, "legacy presets decode as finite")
// Timing must stay accurate even while the UI thread is occupied.
log.reset()
clicker.executeScheme(scheme(count: 100, duration: 1))
Thread.sleep(forTimeInterval: 0.2)
check(events.count >= 15, "clicks continue while the main thread is blocked")
runLoop(1.0)
let timed = log.snapshot
let measuredCPS = Double(timed.count - 1) / (timed.last!.1 - timed.first!.1)
check(timed.count == 100 && measuredCPS > 90 && measuredCPS < 110,
      "100 CPS timing measured: \(String(format: "%.2f", measuredCPS)) CPS")

for button in [MouseButton.left, .right] {
    let (down, up) = MouseClicker.clickEvents(button: button, at: CGPoint(x: 10, y: 10))!
    check(down.flags.isEmpty && up.flags.isEmpty, "click events carry no shortcut modifiers")
    check(down.getIntegerValueField(.mouseEventClickState) == 1 &&
          up.getIntegerValueField(.mouseEventClickState) == 1, "click events are ordinary single clicks")
    check(down.type == button.downEventType && up.type == button.upEventType, "correct mouse button events")
}

let monitor = HotkeyMonitor()
var triggers = 0
let trigger = Hotkey(keyCode: 8, commandKey: true, controlKey: true)
monitor.registerHotkey(trigger) { triggers += 1 }
let key = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true)!
key.flags = [.maskCommand, .maskControl, .maskAlphaShift]
check(monitor.handleEvent(type: .keyDown, event: key) == nil, "matched shortcut is consumed")
runLoop(0.01)
check(triggers == 1, "shortcut with Caps Lock triggers once")
check(monitor.handleEvent(type: .keyDown, event: key) == nil, "held shortcut is consumed without retrigger")
runLoop(0.01)
check(triggers == 1, "holding the key does not toggle the clicker repeatedly")
check(monitor.handleEvent(type: .keyUp, event: key) == nil, "matching key release is consumed")
_ = monitor.handleEvent(type: .keyDown, event: key)
monitor.stopMonitoring()
runLoop(0.01)
check(triggers == 1, "stopping monitoring cancels queued shortcut actions")

var escapes = 0
monitor.onEscape = { escapes += 1 }
monitor.isClicking = { true }
let escape = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!
check(monitor.handleEvent(type: .keyDown, event: escape) == nil, "Esc is consumed during clicking")
runLoop(0.01)
check(escapes == 1, "Esc reaches the stop handler")
_ = monitor.handleEvent(type: .keyUp, event: escape)
monitor.isClicking = { false }
check(monitor.handleEvent(type: .keyDown, event: escape) != nil, "idle Esc passes through")
check(Hotkey.keyA != Hotkey.unassignedKey, "A is a valid key, not the unassigned sentinel")
print("All ClickLoop smoke checks passed; no mouse events were posted.")
