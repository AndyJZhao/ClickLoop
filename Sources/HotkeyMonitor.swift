import Foundation
import CoreGraphics
import AppKit

/// 全局快捷键监听器
class HotkeyMonitor {
    var onEscape: (() -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeyHandlers: [Hotkey: () -> Void] = [:]

    init() {}

    /// 注册快捷键及其回调
    func registerHotkey(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        hotkeyHandlers[hotkey] = handler
    }

    /// 开始监听全局按键事件
    func startMonitoring() {
        // 如果已经在监听，先停止
        if eventTap != nil {
            print("⚠️  检测到已有监听器，先停止旧的")
            stopMonitoring()
        }

        // 检查辅助功能权限
        guard checkAccessibilityPermission() else {
            print("❌ 错误: 请在系统偏好设置 -> 安全性与隐私 -> 辅助功能 中授予本应用权限")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // 创建事件回调
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handleEvent(proxy: proxy, type: type, event: event)
        }

        // 创建事件监听器
        // ⚠️ 使用 .cghidEventTap 以支持后台运行时的全局快捷键监听
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,  // 系统级事件监听，支持后台运行
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPointer
        )

        guard let eventTap = eventTap else {
            print("❌ 错误: 无法创建事件监听器，请检查辅助功能权限")
            return
        }

        // 添加到运行循环
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("🚀 全局快捷键监听已启动，已注册 \(hotkeyHandlers.count) 个快捷键")
    }

    /// 停止监听
    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        // ⚠️ 关键：清理已注册的快捷键，防止重复注册
        let count = hotkeyHandlers.count
        hotkeyHandlers.removeAll()

        print("⏹️ 全局快捷键监听已停止，已清理 \(count) 个快捷键")
    }

    /// 处理按键事件
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        // 如果不是按键按下事件，直接传递
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return Unmanaged.passUnretained(event)
        }
        if keyCode == 53 {
            DispatchQueue.main.async { [weak self] in self?.onEscape?() }
            return Unmanaged.passUnretained(event)
        }

        // 构造当前按键信息
        let currentHotkey = Hotkey(
            keyCode: keyCode,
            commandKey: flags.contains(.maskCommand),
            optionKey: flags.contains(.maskAlternate),
            controlKey: flags.contains(.maskControl),
            shiftKey: flags.contains(.maskShift)
        )

        // 检查是否匹配已注册的快捷键
        if let handler = hotkeyHandlers[currentHotkey] {
            print("⌨️  触发快捷键: keyCode=\(keyCode)")
            // 在主线程执行，确保对象生命周期安全
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                handler()
            }
            // 拦截该事件，防止传递到其他应用
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(event)
    }

    /// 检查辅助功能权限
    private func checkAccessibilityPermission() -> Bool {
        // 直接使用系统权限请求（带提示弹窗）
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options) as Bool
    }

    deinit {
        stopMonitoring()
    }
}
