import Foundation
import Combine
import AppKit

class ClickerViewModel: ObservableObject {
    @Published var schemes: [ClickScheme] = []
    @Published var isRunning: Bool = false
    @Published var isClicking: Bool = false

    private let schemeManager = SchemeManager()
    private let hotkeyMonitor = HotkeyMonitor()
    private let mouseClicker = MouseClicker()

    init() {
        mouseClicker.onRunningChanged = { [weak self] running in self?.isClicking = running }
        hotkeyMonitor.onEscape = { [weak self] in self?.stopClicking() }
        loadSchemes()

        // 如果有已启用的方案，自动启动监听器
        let enabledSchemes = schemes.filter { $0.isEnabled }
        if !enabledSchemes.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startClicker()
            }
        }
    }

    deinit {
        // 停止监听
        if isRunning {
            hotkeyMonitor.stopMonitoring()
        }
    }

    // MARK: - Scheme Management

    func loadSchemes() {
        schemes = schemeManager.getAllSchemes()
    }

    func addScheme(_ scheme: ClickScheme) {
        let result = schemeManager.addScheme(scheme)

        switch result {
        case .success:
            loadSchemes()

            // 如果正在运行，注册新快捷键
            if isRunning {
                registerHotkey(for: scheme)
            }
        case .failure(let error):
            showAlert(title: "添加方案失败", message: error.localizedDescription)
        }
    }

    func updateScheme(_ oldScheme: ClickScheme, with newScheme: ClickScheme) {
        if let index = schemes.firstIndex(where: { $0.id == oldScheme.id }) {
            let result = schemeManager.updateScheme(at: index, with: newScheme)

            switch result {
            case .success:
                // ⚠️ 关键：立即更新内存中的方案数组，确保 UI 立即刷新
                schemes[index] = newScheme

                // 如果正在运行，需要重新注册所有快捷键以确保使用最新配置
                if isRunning {
                    print("🔄 方案已更新，重新启动监听器以应用新配置")
                    stopClicker()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.startClicker()
                    }
                }
            case .failure(let error):
                showAlert(title: "更新方案失败", message: error.localizedDescription)
            }
        }
    }

    func deleteScheme(_ scheme: ClickScheme) {
        if let index = schemes.firstIndex(where: { $0.id == scheme.id }) {
            if schemeManager.deleteScheme(at: index) {
                loadSchemes()

                // 如果正在运行，需要重新注册快捷键
                if isRunning {
                    stopClicker()
                    if !schemes.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.startClicker()
                        }
                    }
                }
            }
        }
    }

    func toggleScheme(_ scheme: ClickScheme) {
        guard let index = schemes.firstIndex(where: { $0.id == scheme.id }) else { return }

        // ⚠️ 关键：直接切换状态（立即生效）
        schemes[index].isEnabled.toggle()

        let newState = schemes[index].isEnabled
        print("🔄 切换方案状态: \(scheme.name), 新状态: \(newState ? "启用" : "禁用")")

        _ = schemeManager.updateScheme(at: index, with: schemes[index])

        // 更新监听器状态 - 统一处理：重新启动以确保快捷键正确注册
        let enabledCount = schemes.filter { $0.isEnabled }.count
        print("📊 当前已启用方案数: \(enabledCount)")

        if enabledCount == 0 {
            print("⏹️ 所有方案已禁用，停止监听器")
            stopClicker()
        } else {
            print("🔄 重新启动监听器以确保快捷键正确注册")
            if isRunning {
                stopClicker()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startClicker()
            }
        }
    }

    func enableAllSchemes() {
        for (index, scheme) in schemes.enumerated() {
            if !scheme.isEnabled {
                var updatedScheme = scheme
                updatedScheme.isEnabled = true
                _ = schemeManager.updateScheme(at: index, with: updatedScheme)
            }
        }
        loadSchemes()

        // 启动全局监听
        if !isRunning {
            startClicker()
        } else {
            // 重新注册所有快捷键
            stopClicker()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startClicker()
            }
        }
    }

    // MARK: - 快捷键录制支持

    func pauseHotkeyMonitoring() {
        stopClicking()
        if isRunning {
            hotkeyMonitor.stopMonitoring()
            print("⏸️ 暂停快捷键监听（录制中）")
        }
    }

    func resumeHotkeyMonitoring() {
        if isRunning {
            // ⚠️ 关键：需要重新启动监听并注册所有快捷键
            hotkeyMonitor.startMonitoring()

            // 重新注册所有已启用方案的快捷键
            let enabledSchemes = schemes.filter { $0.isEnabled }
            for scheme in enabledSchemes {
                registerHotkey(for: scheme)
            }
            print("▶️ 恢复快捷键监听，已注册 \(enabledSchemes.count) 个方案")
        }
    }

    func disableAllSchemes() {
        for (index, scheme) in schemes.enumerated() {
            if scheme.isEnabled {
                var updatedScheme = scheme
                updatedScheme.isEnabled = false
                _ = schemeManager.updateScheme(at: index, with: updatedScheme)
            }
        }
        loadSchemes()

        // 停止全局监听
        if isRunning {
            stopClicker()
        }
    }

    // MARK: - Clicker Control

    func startClicker() {
        let enabledSchemes = schemes.filter { $0.isEnabled }

        // ⚠️ 关键：如果没有启用的方案，直接返回（不弹窗提示）
        guard !enabledSchemes.isEmpty else {
            return
        }

        hotkeyMonitor.stopMonitoring()
        // 仅注册已启用方案的快捷键
        for scheme in enabledSchemes {
            registerHotkey(for: scheme)
        }

        hotkeyMonitor.startMonitoring()

        // 只有在权限已授予的情况下才标记为运行中
        if AXIsProcessTrusted() {
            isRunning = true
            print("✅ 监听器启动完成，isRunning = \(isRunning)")
            showNotification(title: "ClickLoop \(L.started)", message: "\(L.loaded) \(enabledSchemes.count) \(L.schemes)")
        } else {
            print("❌ 监听器启动失败：权限未授予")
        }
    }

    func stopClicking() {
        mouseClicker.stop()
    }

    func stopClicker() {
        stopClicking()
        hotkeyMonitor.stopMonitoring()
        isRunning = false

        showNotification(title: "ClickLoop \(L.stopped)", message: L.clickerStopped)
    }

    private func registerHotkey(for scheme: ClickScheme) {
        let schemeId = scheme.id  // 捕获ID而不是整个scheme
        hotkeyMonitor.registerHotkey(scheme.hotkey) { [weak self] in
            guard let self = self else { return }

            // 通过ID查找最新的scheme，确保使用最新的参数
            guard let currentScheme = self.schemes.first(where: { $0.id == schemeId }) else {
                return
            }

            guard currentScheme.isEnabled else { return }
            if self.mouseClicker.activeSchemeID == currentScheme.id {
                self.stopClicking()
                return
            }

            // 强引用 mouseClicker 以确保执行期间不被释放
            let clicker = self.mouseClicker
            clicker.executeScheme(currentScheme)

            self.showNotification(
                title: L.executing,
                message: currentScheme.isUnlimited ? L.unlimitedDescription(cps: 1 / currentScheme.clickInterval) : "\(currentScheme.name) - \(currentScheme.clickCount)\(LocalizationManager.shared.currentLanguage == .chinese ? "次" : "x")/\(String(format: "%.1f", currentScheme.totalDuration))\(LocalizationManager.shared.currentLanguage == .chinese ? "秒" : "s")"
            )
        }
    }

    // MARK: - Helper Methods

    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        // 使用系统成功音效（Glass 音效）
        notification.soundName = "Glass"

        NSUserNotificationCenter.default.deliver(notification)
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
