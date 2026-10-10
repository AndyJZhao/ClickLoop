import Foundation
import CoreGraphics
import AppKit

/// 鼠标点击执行器
class MouseClicker {
    private var timer: Timer?
    private(set) var activeSchemeID: UUID?
    var onRunningChanged: ((Bool) -> Void)?
    private let clickAction: (MouseButton) -> Void
    private let startSound: () -> Void

    init(clickAction: @escaping (MouseButton) -> Void = MouseClicker.simulateClick,
         startSound: @escaping () -> Void = { NSSound(named: "Tink")?.play() }) {
        self.clickAction = clickAction
        self.startSound = startSound
    }

    /// Called on the main run loop, alongside hotkeys and UI stop actions.
    func executeScheme(_ scheme: ClickScheme) {
        stop()
        guard ClickScheme.isValidTiming(clickCount: scheme.clickCount,
                                        duration: scheme.totalDuration) else { return }
        activeSchemeID = scheme.id
        onRunningChanged?(true)
        startSound()
        var remaining = scheme.clickCount
        let timer = Timer(timeInterval: scheme.clickInterval, repeats: true) { [weak self] timer in
            guard let self = self, self.activeSchemeID == scheme.id else {
                timer.invalidate()
                return
            }
            self.clickAction(scheme.button)
            if !scheme.isUnlimited {
                remaining -= 1
                if remaining == 0 { self.stop() }
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        activeSchemeID = nil
        onRunningChanged?(false)
    }

    deinit { timer?.invalidate() }

    /// 模拟鼠标点击
    static func simulateClick(button: MouseButton) {
        // 获取当前鼠标位置（实时获取，允许用户移动鼠标）
        guard let currentLocation = CGEvent(source: nil)?.location else { return }

        // 创建鼠标按下事件（在当前位置点击，不强制移动鼠标）
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: button.downEventType,
            mouseCursorPosition: currentLocation,
            mouseButton: button == .left ? .left : .right
        ) else {
            print("❌ 无法创建鼠标按下事件")
            return
        }

        // 创建鼠标抬起事件
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: button.upEventType,
            mouseCursorPosition: currentLocation,
            mouseButton: button == .left ? .left : .right
        ) else {
            print("❌ 无法创建鼠标抬起事件")
            return
        }

        // 发送事件到系统
        mouseDown.post(tap: .cghidEventTap)

        // 添加极小延迟（模拟真实点击的按下-抬起过程）
        Thread.sleep(forTimeInterval: 0.001)

        mouseUp.post(tap: .cghidEventTap)
    }

}
