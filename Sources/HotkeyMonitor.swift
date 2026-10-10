import Foundation
import CoreGraphics
import AppKit

class HotkeyMonitor {
    var onEscape: (() -> Void)?
    var isClicking: (() -> Bool)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyHandlers: [Hotkey: () -> Void] = [:]
    private var generation = UUID()
    private var pressedKeys: Set<UInt16> = []

    func registerHotkey(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        hotkeyHandlers[hotkey] = handler
    }

    @discardableResult
    func startMonitoring() -> Bool {
        if let eventTap = eventTap { return CGEvent.tapIsEnabled(tap: eventTap) }
        guard AXIsProcessTrusted() else { return false }
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask), callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func stopMonitoring() {
        generation = UUID()
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        hotkeyHandlers.removeAll()
        pressedKeys.removeAll()
    }

    // Internal for regression tests; nil means the matched key is consumed.
    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            pressedKeys.removeAll()
            if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyUp {
            return pressedKeys.remove(keyCode) != nil ? nil : Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        if pressedKeys.contains(keyCode) { return nil }
        let flags = event.flags
        let hotkey = Hotkey(keyCode: keyCode, commandKey: flags.contains(.maskCommand),
                            optionKey: flags.contains(.maskAlternate), controlKey: flags.contains(.maskControl),
                            shiftKey: flags.contains(.maskShift))
        let handler = keyCode == 53 && isClicking?() == true ? onEscape : hotkeyHandlers[hotkey]
        guard let handler = handler else { return Unmanaged.passUnretained(event) }
        pressedKeys.insert(keyCode)
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            let generation = generation
            DispatchQueue.main.async { [weak self] in
                guard self?.generation == generation else { return }
                handler()
            }
        }
        return nil
    }

    deinit { stopMonitoring() }
}
