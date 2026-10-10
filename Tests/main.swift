import Foundation

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
var events: [MouseButton] = []
var running = false
let clicker = MouseClicker(clickAction: { events.append($0) }, startSound: {})
clicker.onRunningChanged = { running = $0 }
clicker.executeScheme(scheme())
runLoop(0.15)
check(events.count == 3 && !running, "finite execution stops at the requested count")

events = []
clicker.executeScheme(scheme(count: 1, duration: 0.02, unlimited: true))
runLoop(0.12)
check(events.count >= 4 && running, "infinite execution continues past the configured count")
clicker.stop()
let stoppedCount = events.count
runLoop(0.06)
check(events.count == stoppedCount && !running, "stop cancels future clicks")

events = []
clicker.executeScheme(scheme(count: 2, duration: 600))
check(events.count == 1 && running, "long duration starts immediately")
let beforeStop = Date()
clicker.stop()
check(Date().timeIntervalSince(beforeStop) < 0.1 && !running, "long interval cancels immediately")
runLoop(0.03)
check(events.count == 1, "cancelled long run produces no extra clicks")

events = []
clicker.executeScheme(scheme(count: 1, duration: 0.02, unlimited: true))
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
print("All ClickLoop smoke checks passed; no mouse events were posted.")
