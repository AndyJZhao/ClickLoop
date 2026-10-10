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
            button: MouseButton = .left, cps: Double? = nil) -> ClickScheme {
    ClickScheme(name: "Test", button: button, targetCPS: cps ?? Double(count) / duration,
                totalDuration: duration, hotkey: Hotkey(keyCode: 18, optionKey: true),
                isUnlimited: unlimited)
}

check(ClickScheme.isValidTiming(targetCPS: 10, duration: 600), "600-second duration accepted")
check(ClickScheme.isValidTiming(targetCPS: 10, duration: 86400), "24-hour duration accepted")
check(ClickScheme.isValidTiming(targetCPS: 200, duration: 1), "200 CPS accepted")
for duration in [0.0, -1.0, Double.nan, Double.infinity, Double.greatestFiniteMagnitude] {
    check(!ClickScheme.isValidTiming(targetCPS: 10, duration: duration), "invalid duration rejected: \(duration)")
}
for cps in [0.0, -1.0, 201, Double.nan, Double.infinity, Double.leastNonzeroMagnitude] {
    check(!ClickScheme.isValidTiming(targetCPS: cps, duration: 1), "invalid CPS rejected: \(cps)")
}
check(scheme(count: 1, duration: 5, unlimited: true).clickInterval == 5, "one-click infinite rate preserved")
let shortPreset = scheme(duration: 1, cps: 100)
let longPreset = scheme(duration: 10, cps: 100)
check(shortPreset.clickInterval == 0.01 && longPreset.clickInterval == 0.01,
      "changing duration keeps target CPS unchanged")
check(shortPreset.clickCount == 100 && longPreset.clickCount == 1000,
      "finite count is calculated from target CPS and duration")
check(scheme(duration: 1, cps: 2.5).clickInterval == 0.4 &&
      scheme(duration: 1, cps: 2.5).clickCount == 3, "fractional CPS is not rounded to an integer rate")

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
let saved = scheme(duration: 600, unlimited: true, cps: 2.5)
_ = storage.addScheme(saved)
let reloaded = SchemeManager(directoryURL: directory).getAllSchemes()
check(reloaded.contains(saved), "target CPS, unlimited mode, duration and UUID survive persistence")

// Older SnapClick-format records have no isUnlimited property.
let path = directory.appendingPathComponent("schemes.json")
var records = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [[String: Any]]
for index in records.indices {
    records[index].removeValue(forKey: "isUnlimited")
    records[index].removeValue(forKey: "targetCPS")
    records[index]["clickCount"] = 100
    records[index]["totalDuration"] = 10.0
}
try JSONSerialization.data(withJSONObject: records).write(to: path)
let legacy = SchemeManager(directoryURL: directory).getAllSchemes()
check(legacy.count == records.count && legacy.allSatisfy { !$0.isUnlimited }, "legacy presets decode as finite")
check(legacy.allSatisfy { $0.targetCPS == 10 && $0.clickInterval == 0.1 },
      "legacy 100 clicks / 10 seconds migrates to 10 CPS")
let migratedStorage = SchemeManager(directoryURL: directory)
_ = migratedStorage.updateScheme(at: 0, with: legacy[0])
check(SchemeManager(directoryURL: directory).getAllSchemes() == legacy,
      "migrated presets survive save and reload without changing IDs or rates")
// Timing must stay accurate even while the UI thread is occupied.
log.reset()
clicker.executeScheme(scheme(duration: 1, cps: 100))
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
// Feed movement directly through the event handler without posting any system input.
var movementStops = 0
monitor.isClicking = { running }
monitor.onMouseMovement = { movementStops += 1; clicker.stop() }
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                   mouseCursorPosition: CGPoint(x: 20, y: 20), mouseButton: .left)!
_ = monitor.handleEvent(type: .mouseMoved, event: move)
check(movementStops == 0, "idle movement does not invoke stop")
for unlimited in [false, true] {
    for type in [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
        log.reset()
        clicker.executeScheme(scheme(count: 100, duration: 1, unlimited: unlimited))
        runLoop(0.03)
        check(running && !events.isEmpty, "run starts before movement")
        let stopsBefore = movementStops
        let forwarded = monitor.handleEvent(type: type, event: move)
        check(forwarded?.takeUnretainedValue() === move, "movement passes through to target app")
        check(!running && clicker.activeSchemeID == nil && movementStops == stopsBefore + 1,
              "movement \(type.rawValue) immediately clears active state (unlimited: \(unlimited))")
        let countAfterMovement = events.count
        runLoop(0.04)
        check(events.count == countAfterMovement, "no clicks follow movement stop")
    }
}
clicker.executeScheme(scheme(count: 1, duration: 0.02, unlimited: true))
for type in [CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp] {
    _ = monitor.handleEvent(type: type, event: move)
}
check(running, "ordinary click events do not stop clicking")
clicker.stop()
print("All ClickLoop smoke checks passed; no mouse events were posted.")
